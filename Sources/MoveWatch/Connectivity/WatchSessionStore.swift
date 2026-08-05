import Foundation
import Combine
import WatchConnectivity
import MoveShared

final class WatchSessionStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published var nextExerciseName = "Prochain mouvement"
    private let queue = WatchCommandQueue()
    override init() { super.init(); guard WCSession.isSupported() else { return }; WCSession.default.delegate = self; WCSession.default.activate() }
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let data = message["command"] as? Data, let command = try? JSONDecoder().decode(WatchCommand.self, from: data) else { return }
        Task { await queue.enqueue(command) }
    }
    func send(_ action: WatchCommandAction, reminderID: String? = nil) { let command = WatchCommand(action: action, reminderID: reminderID); WCSession.default.sendMessage(["command": (try? JSONEncoder().encode(command)) as Any], replyHandler: nil) }
}
