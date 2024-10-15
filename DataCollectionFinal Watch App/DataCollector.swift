import Foundation
import CoreMotion
import HealthKit

class DataCollector: ObservableObject {
    private let motionManager = CMMotionManager()
    private let motionQueue = OperationQueue()
    private var data: [SensorData] = []
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var heartRateSamples: [HKQuantitySample] = []

    init() {
        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0 // 50 Hz
    }

    func startCollecting() {
        startMotionUpdates()
        startHeartRateQuery()
    }

    func stopCollecting() {
        stopMotionUpdates()
        stopHeartRateQuery()
    }

    func saveData() {
        let csvString = dataToCSV()
        saveCSV(csvString: csvString, fileName: "bio_data.csv")
        data.removeAll()
    }

    private func startMotionUpdates() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] (deviceMotion, error) in
                guard let self = self, let deviceMotion = deviceMotion else { return }
                let timestamp = Date()
                let sensorData = SensorData(timestamp: timestamp,
                                            acceleration: deviceMotion.userAcceleration,
                                            rotationRate: deviceMotion.rotationRate)
                DispatchQueue.main.async {
                    self.data.append(sensorData)
                }
            }
        }
    }

    private func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }

    private func dataToCSV() -> String {
        var csvString = "Timestamp,AccelerationX,AccelerationY,AccelerationZ,RotationRateX,RotationRateY,RotationRateZ,HeartRate\n"
        let dateFormatter = ISO8601DateFormatter()

        for entry in data {
            let timestamp = dateFormatter.string(from: entry.timestamp)
            let accX = entry.acceleration?.x ?? 0
            let accY = entry.acceleration?.y ?? 0
            let accZ = entry.acceleration?.z ?? 0
            let rotX = entry.rotationRate?.x ?? 0
            let rotY = entry.rotationRate?.y ?? 0
            let rotZ = entry.rotationRate?.z ?? 0
            let heartRate = entry.heartRate ?? 0.0
            let line = "\(timestamp),\(accX),\(accY),\(accZ),\(rotX),\(rotY),\(rotZ),\(heartRate)\n"
            csvString += line
        }
        return csvString
    }

    private func saveCSV(csvString: String, fileName: String) {
        let fileManager = FileManager.default
        do {
            let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            if let documentDirectory = urls.first {
                let fileURL = documentDirectory.appendingPathComponent(fileName)
                try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
                print("CSV file saved at \(fileURL)")
            }
        } catch {
            print("Error saving CSV file: \(error)")
        }
    }

    // Heart rate collection methods
    private func startHeartRateQuery() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("Health data not available")
            return
        }

        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let dataTypes = Set([heartRateType])

        healthStore.requestAuthorization(toShare: nil, read: dataTypes) { (success, error) in
            if success {
                self.createHeartRateStreamingQuery()
            } else {
                print("HealthKit authorization failed: \(String(describing: error))")
            }
        }
    }

    private func stopHeartRateQuery() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
    }

    private func createHeartRateStreamingQuery() {
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: Date(), end: nil, options: .strictStartDate)

        heartRateQuery = HKAnchoredObjectQuery(type: heartRateType, predicate: predicate, anchor: nil, limit: HKObjectQueryNoLimit) { (query, samplesOrNil, _, _, _) in
            self.processHeartRateSamples(samples: samplesOrNil)
        }

        heartRateQuery?.updateHandler = { (query, samplesOrNil, _, _, _) in
            self.processHeartRateSamples(samples: samplesOrNil)
        }

        if let query = heartRateQuery {
            healthStore.execute(query)
        }
    }

    private func processHeartRateSamples(samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample] else { return }

        for sample in samples {
            let heartRateUnit = HKUnit(from: "count/min")
            let heartRate = sample.quantity.doubleValue(for: heartRateUnit)
            let timestamp = sample.endDate

            DispatchQueue.main.async {
                // Find the closest timestamp in data array
                if let lastIndex = self.data.lastIndex(where: { abs($0.timestamp.timeIntervalSince(timestamp)) < 1.0 }) {
                    self.data[lastIndex].heartRate = heartRate
                } else {
                    // If no matching timestamp, create a new entry
                    let sensorData = SensorData(timestamp: timestamp, acceleration: nil, rotationRate: nil, heartRate: heartRate)
                    self.data.append(sensorData)
                }
            }
        }
    }
}

struct SensorData {
    var timestamp: Date
    var acceleration: CMAcceleration?
    var rotationRate: CMRotationRate?
    var heartRate: Double?
}
