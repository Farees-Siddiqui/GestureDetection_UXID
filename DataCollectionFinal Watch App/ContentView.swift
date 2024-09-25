import SwiftUI
import WatchConnectivity

struct ContentView: View {
    @State private var gridSize = 2
    @State private var highlightedIndex: (Int, Int)? = nil
    @State private var iterationCount = 0
    let maxIterations = 3 // Change this value to set the number of iterations before the grid size changes
    @State private var isHomingSquareHighlighted = true
    @State private var isRandomSquareHighlighted = false
    @State private var isIterationActive = false
    @State private var isRunning = false // Add this state variable
    
    @StateObject private var connectivityManager = ConnectivityManager.shared
    @StateObject private var sessionManager = ExtendedRuntimeSessionManager() // Add session manager

    // Timing values for easy tweaking
    let resetDuration: Double = 0.25

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let buttonSize = size / CGFloat(gridSize) * 0.9
            let padding = size / CGFloat(gridSize) * 0.1 / 2

            ZStack {
                Color.white // Set background to white
                    .edgesIgnoringSafeArea(.all) // Ignore safe area to cover entire screen

                VStack(spacing: padding) {
                    ForEach(0..<gridSize, id: \.self) { row in
                        HStack(spacing: padding) {
                            ForEach(0..<gridSize, id: \.self) { column in
                                let isHighlighted = highlightedIndex != nil && highlightedIndex! == (row, column)
                                Button(action: {
                                    // Action for button tap
                                    handleTap()
                                }) {
                                    Rectangle()
                                        .foregroundColor(isHighlighted ? Color.green : .clear) // Highlight the square if it matches the pattern
                                        .frame(width: buttonSize, height: buttonSize)
                                        .scaleEffect(isHighlighted ? 1.1 : 1.0) // Scale up if highlighted
                                        .animation(.easeInOut(duration: 0.3), value: isHighlighted) // Animation
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
                sessionManager.startSession() // Start session
                highlightHomingSquare()
            }
            .onDisappear {
                sessionManager.invalidateSession() // Invalidate session
            }
            .onChange(of: connectivityManager.isRunning) { newValue in
                isRunning = newValue
                // Additional logic when isRunning changes
                if isRunning {
                    startIteration()
                } else {
                    stopIteration()
                }
            }
        }
    }

    func highlightHomingSquare() {
        switch gridSize {
        case 2, 4:
            highlightedIndex = (0, 0) // First square for 2x2 and 4x4 grid
        case 3:
            highlightedIndex = (gridSize / 2, gridSize / 2) // Middle square for 3x3 grid
        default:
            highlightedIndex = nil
        }
        isHomingSquareHighlighted = true
        isRandomSquareHighlighted = false
        isIterationActive = false
    }

    func handleTap() {
        // This function can remain unchanged or handle local tap actions
    }

    func startIteration() {
        // User tapped to start iteration
        isHomingSquareHighlighted = false
        isIterationActive = true
        DispatchQueue.main.asyncAfter(deadline: .now() + resetDuration + 0.5) {
            highlightedIndex = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + resetDuration) {
                highlightRandomSquare()
            }
        }
    }

    func stopIteration() {
        // User tapped to end iteration
        isIterationActive = false
        isRandomSquareHighlighted = false
        highlightedIndex = nil
        iterationCount += 1

        // Check if we've reached the maximum number of iterations
        if iterationCount >= maxIterations {
            iterationCount = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + resetDuration) {
                switch gridSize {
                case 2:
                    gridSize = 3
                case 3:
                    gridSize = 4
                default:
                    gridSize = 2
                }
                highlightHomingSquare()
            }
        } else {
            highlightHomingSquare()
        }
    }

    func highlightRandomSquare() {
        let randomRow = Int.random(in: 0..<gridSize)
        let randomColumn = Int.random(in: 0..<gridSize)
        highlightedIndex = (randomRow, randomColumn)
        isRandomSquareHighlighted = true
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
                // You can add additional logic here to handle the state change
                print("Received message from iPhone: isRunning = \(isRunning)")
            }
        }
    }
}
