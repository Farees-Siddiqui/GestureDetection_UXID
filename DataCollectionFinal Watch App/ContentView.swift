import SwiftUI
import WatchConnectivity

struct ContentView: View {
    @State private var gridSize = 0 // Start with split layouts
    @State private var highlightedIndex: (Int, Int)? = nil
    @State private var iterationCount = 0
    let maxIterations = 3 // Number of iterations before layout changes
    @State private var isRunning = false

    // Track how many times each square has been highlighted
    @State private var highlightCounts: [[Int]] = []

    @StateObject private var connectivityManager = ConnectivityManager.shared
    @StateObject private var sessionManager = ExtendedRuntimeSessionManager()

    // Timing values for easy tweaking
    let highlightDuration: Double = 0.5
    let delayBetweenHighlights: Double = 0.25

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
            let size = min(geometry.size.width, geometry.size.height)
            let rows = layout.rows
            let columns = layout.columns
            let buttonSize = size / CGFloat(max(rows, columns)) * 0.9
            let padding = size / CGFloat(max(rows, columns)) * 0.1 / 2

            ZStack {
                Color.white // Set background to white
                    .edgesIgnoringSafeArea(.all) // Ignore safe area to cover entire screen

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
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .onAppear {
                sessionManager.startSession()
                initializeHighlightCounts()
                // No initial highlights
            }
            .onDisappear {
                sessionManager.invalidateSession()
            }
            .onChange(of: connectivityManager.isRunning) { newValue in
                isRunning = newValue
                if isRunning {
                    startIteration()
                } else {
                    stopIteration()
                }
            }
        }
    }

    func initializeHighlightCounts() {
        // Initialize the highlight counts to track each square
        highlightCounts = Array(repeating: Array(repeating: 0, count: layout.columns), count: layout.rows)
    }

    func highlightHomingSquare() {
        switch gridSize {
        case 0: // Horizontal split
            highlightedIndex = (0, 0) // Highlight left side first
        case 1: // Vertical split
            highlightedIndex = (0, 0) // Highlight top side first
        case 2, 4:
            highlightedIndex = (0, 0) // First square for 2x2 and 4x4 grid
        case 3:
            highlightedIndex = (gridSize / 2, gridSize / 2) // Middle square for 3x3 grid
        default:
            highlightedIndex = nil
        }
    }

    func handleTap() {
        // This function can remain unchanged or handle local tap actions
    }

    func startIteration() {
        // Cancel any pending tasks
        pendingWorkItem?.cancel()
        pendingWorkItem = nil

        // Start the sequence of highlighting
        highlightHomingSquare()

        // Schedule the sequence
        let workItem = DispatchWorkItem {
            // Remove homing square highlight
            self.highlightedIndex = nil

            // Delay before highlighting random square
            DispatchQueue.main.asyncAfter(deadline: .now() + self.delayBetweenHighlights) {
                // Highlight random square
                self.highlightRandomSquare()

                // The iteration now waits for the Stop button
            }
        }

        pendingWorkItem = workItem

        // Remove homing square highlight after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + self.highlightDuration, execute: workItem)
    }

    func stopIteration() {
        // Cancel any pending tasks
        pendingWorkItem?.cancel()
        pendingWorkItem = nil

        // Clear any highlights
        highlightedIndex = nil

        // Increment iteration count
        iterationCount += 1

        if iterationCount >= maxIterations {
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
    }

    func highlightRandomSquare() {
        // Find the square with the fewest highlights
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

        // Select a random square from the least highlighted squares
        if let randomSquare = leastHighlightedSquares.randomElement() {
            highlightedIndex = randomSquare
            highlightCounts[randomSquare.0][randomSquare.1] += 1
        }
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
