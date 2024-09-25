import WatchKit

class ExtendedRuntimeSessionManager: NSObject, ObservableObject, WKExtendedRuntimeSessionDelegate {
    var extendedRuntimeSession: WKExtendedRuntimeSession?
    
    override init() {
        super.init()
        extendedRuntimeSession = WKExtendedRuntimeSession()
        extendedRuntimeSession?.delegate = self
    }
    
    func startSession() {
        extendedRuntimeSession?.start()
    }
    
    func invalidateSession() {
        extendedRuntimeSession?.invalidate()
    }
    
    // MARK: - WKExtendedRuntimeSessionDelegate
    
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("Extended runtime session started")
    }
    
    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("Extended runtime session will expire soon")
    }
    
    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        print("Extended runtime session invalidated with reason: \(reason.rawValue)")
        if let error = error {
            print("Error: \(error.localizedDescription)")
        }
    }
}
