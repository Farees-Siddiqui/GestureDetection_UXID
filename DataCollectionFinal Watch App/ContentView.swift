import SwiftUI
import WatchConnectivity
import CoreMotion
import HealthKit

struct ContentView: View {
    @State private var gridSize = 0 // Start with split layouts
    @State private var highlightedIndex: (Int, Int)? = nil
    @State private var iterationCount = 0
    let maxIterations = 1 // Number of iterations before layout changes
    @State private var isRunning = false
    @State private var isAnimating = false // Added for animation
    @State private var showTimer = false // To display the timer screen
    
    // Track how many times each square has been highlighted
    @State private var highlightCounts: [[Int]] = []

    @StateObject private var connectivityManager = ConnectivityManager.shared
    @StateObject private var sessionManager = ExtendedRuntimeSessionManager()
    @StateObject private var dataCollector = DataCollector() // Added data collector

    // Timing values for easy tweaking
    let highlightDuration: Double = 0.5
    let delayBetweenHighlights: Double = 0.1

    // For managing pending tasks
    @State private var pendingWorkItem: DispatchWorkItem?

    // Computed properties to calculate rows, columns, and button size based on gridSize
    var layout: (rows: Int, columns: Int) {
        switch gridSize {
        case 0: // Horizontal split
            return (1, 2)
        case 1: // Vertical split
            return (2, 1)
        case 2: // 2x2 grid
            return (2, 2)
        case 3: // 3x3 grid
            return (3, 3)
        default:
            return (2, 2)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let size = min(width, height)
            let rows = layout.rows
            let columns = layout.columns
            let buttonSize = size / CGFloat(max(rows, columns)) * 0.9
            let padding = size / CGFloat(max(rows, columns)) * 0.1 / 2

            ZStack {
                if showTimer {
                    // Show the countdown timer when the grid changes
                    TimerView(completion: {
                        showTimer = false
                        startIteration()
                    })
                } else {
                    // Main view for the grid
                    Color.white
                        .edgesIgnoringSafeArea(.all)

                    VStack(spacing: padding) {
                        ForEach(0..<rows, id: \.self) { row in
                            HStack(spacing: padding) {
                                ForEach(0..<columns, id: \.self) { column in
                                    let isHighlighted = highlightedIndex != nil && highlightedIndex! == (row, column)
                                    Button(action: {
                                        handleTap()
                                    }) {
                                        Rectangle()
                                            .foregroundColor(isHighlighted ? Color.green : .clear)
                                            .frame(width: buttonSize, height: buttonSize)
                                            .scaleEffect(isHighlighted ? 1.1 : 1.0)
                                            .animation(.easeInOut(duration: 0.3), value: isHighlighted)
                                    }
                                    .buttonStyle(CustomButtonStyle())
                                }
                            }
                        }
                    }
                    .frame(width: size, height: size)
                    .padding(padding)

                    Circle()
                        .fill(Color.red)
                        .frame(width: 25, height: 25)
                        .position(x: width / 2, y: height / 2)
                        .zIndex(1)
                }
            }
            .frame(width: width, height: height)
        }
        .onAppear {
            sessionManager.startSession()
            initializeHighlightCounts()
        }
        .onDisappear {
            sessionManager.invalidateSession()
        }
        .onChange(of: isRunning) { newValue in
            if newValue {
                startIteration()
                dataCollector.startCollecting()
            } else {
                stopIteration()
                dataCollector.stopCollecting()
            }
        }
        .onChange(of: connectivityManager.isRunning) { newValue in
            isRunning = newValue
        }
    }

    func initializeHighlightCounts() {
        highlightCounts = Array(repeating: Array(repeating: 0, count: layout.columns), count: layout.rows)
    }

    func handleTap() {}

    func startIteration() {
        // Cancel any pending tasks
        pendingWorkItem?.cancel()
        pendingWorkItem = nil

        // Start data collection but do not highlight a square immediately
        dataCollector.startCollecting()

        // Clear any highlighted square when the iteration starts (after the timer)
        highlightedIndex = nil

        // Delay the square highlighting until the actual start signal
        let workItem = DispatchWorkItem {
            // Highlight random square only if running (start signal received)
            if isRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + self.delayBetweenHighlights) {
                    self.highlightRandomSquare()
                }
            }
        }

        // Store the work item and execute it after the specified delay
        pendingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + self.highlightDuration, execute: workItem)
    }


    func stopIteration() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        highlightedIndex = nil
        dataCollector.stopCollecting()
        if let _ = dataCollector.highlightedGestureCode {
            dataCollector.highlightedGestureCode = ""
        }
        iterationCount += 1

        if iterationCount >= maxIterations {
            dataCollector.saveData(forGridSize: gridSize)
            iterationCount = 0
            advanceGridCondition()
        }
    }

    func advanceGridCondition() {
        switch gridSize {
        case 0:
            gridSize = 1
        case 1:
            gridSize = 2
        case 2:
            gridSize = 3
        case 3:
            gridSize = 0
        default:
            gridSize = 0
        }
        initializeHighlightCounts()
        // Show the countdown timer after each grid condition change
        showTimer = true
    }

    func getRandomSquare() -> (Int, Int)? {
        var leastHighlightedSquares: [(Int, Int)] = []
        var minHighlightCount = Int.max
        for row in 0..<layout.rows {
            for column in 0..<layout.columns {
                let count = highlightCounts[row][column]
                if count < minHighlightCount {
                    leastHighlightedSquares = [(row, column)]
                    minHighlightCount = count
                } else if count == minHighlightCount {
                    leastHighlightedSquares.append((row, column))
                }
            }
        }
        return leastHighlightedSquares.randomElement()
    }

    func highlightRandomSquare() {
        let rows = layout.rows
        let columns = layout.columns
        if let randomSquare = getRandomSquare() {
            highlightedIndex = randomSquare
            let row = randomSquare.0
            let column = randomSquare.1
            switch gridSize {
            case 0:
                dataCollector.highlightedGestureCode = (column == 0) ? "L" : "R"
            case 1:
                dataCollector.highlightedGestureCode = (row == 0) ? "T" : "B"
            case 2:
                if row == 0 && column == 0 { dataCollector.highlightedGestureCode = "TL" }
                if row == 0 && column == 1 { dataCollector.highlightedGestureCode = "TR" }
                if row == 1 && column == 0 { dataCollector.highlightedGestureCode = "BL" }
                if row == 1 && column == 1 { dataCollector.highlightedGestureCode = "BR" }
            case 3:
                let codes = ["TL", "TM", "TR", "ML", "MM", "MR", "BL", "BM", "BR"]
                let index = row * columns + column
                dataCollector.highlightedGestureCode = codes[index]
            default:
                dataCollector.highlightedGestureCode = ""
            }
        }
    }
}

struct TimerView: View {
    @State private var timeRemaining: Double = 15
    let completion: () -> Void

    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(lineWidth: 8)
                    .opacity(0.3)
                    .foregroundColor(.blue)

                Circle()
                    .trim(from: 0.0, to: CGFloat(min(self.timeRemaining / 60, 1.0)))
                    .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                    .foregroundColor(.blue)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.linear, value: timeRemaining)

                Text("\(Int(timeRemaining))")
                    .font(.largeTitle)
                    .bold()
            }
            .frame(width: 100, height: 100)
        }
        .onAppear(perform: startTimer)
    }

    func startTimer() {
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if self.timeRemaining == 3 {
                // Trigger haptic feedback (vibration) 3 times
                for _ in 1...3 {
                    WKInterfaceDevice.current().play(.notification)
                    WKInterfaceDevice.current().play(.notification)
                    WKInterfaceDevice.current().play(.notification)
                }
            }

            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                timer.invalidate()
                self.completion()
            }
        }
        timer.fire()
    }
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


class ConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = ConnectivityManager()
    
    @Published var isRunning: Bool = false
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Handle activation completion
        if let error = error {
            print("WCSession activation failed with error: \(error.localizedDescription)")
        } else {
            print("WCSession activated with state: \(activationState.rawValue)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let isRunning = message["isRunning"] as? Bool {
            DispatchQueue.main.async {
                // Update the state based on the received message
                self.isRunning = isRunning
                print("Received message from iPhone: isRunning = \(isRunning)")
            }
        }
    }
}
