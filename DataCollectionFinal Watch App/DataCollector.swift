import Foundation
import CoreMotion

class DataCollector: NSObject, ObservableObject {
    private let motionManager = CMMotionManager()
    private let motionQueue = OperationQueue()
    private var data: [SensorData] = []

    override init() {
        super.init()
        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0 // 50 Hz
    }

    func startCollecting() {
        startMotionUpdates()
    }

    func stopCollecting() {
        stopMotionUpdates()
    }

    func saveData(forGridSize gridSize: Int) {
        let csvString = dataToCSV()
        let fileName = "condition_\(gridSize).csv"
        saveCSV(csvString: csvString, fileName: fileName)
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
        var csvString = "Timestamp,AccelerationX,AccelerationY,AccelerationZ,RotationRateX,RotationRateY,RotationRateZ\n"
        let dateFormatter = ISO8601DateFormatter()

        for entry in data {
            let timestamp = dateFormatter.string(from: entry.timestamp)
            let accX = entry.acceleration?.x ?? 0
            let accY = entry.acceleration?.y ?? 0
            let accZ = entry.acceleration?.z ?? 0
            let rotX = entry.rotationRate?.x ?? 0
            let rotY = entry.rotationRate?.y ?? 0
            let rotZ = entry.rotationRate?.z ?? 0
            let line = "\(timestamp),\(accX),\(accY),\(accZ),\(rotX),\(rotY),\(rotZ)\n"
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
}

struct SensorData {
    var timestamp: Date
    var acceleration: CMAcceleration?
    var rotationRate: CMRotationRate?
}
