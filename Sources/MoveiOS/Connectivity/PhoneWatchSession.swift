import Foundation
import WatchConnectivity
import MoveShared

final class PhoneWatchSession: NSObject, WCSessionDelegate, @unchecked Sendable {
    private let queue = WatchCommandQueue()
    static let shared = PhoneWatchSession()
    private override init() { super.init(); guard WCSession.isSupported() else { return }; WCSession.default.delegate = self; WCSession.default.activate() }
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { flush() }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    func enqueue(_ command: WatchCommand) { Task { await queue.enqueue(command); flush() } }
    private func flush() {
        guard WCSession.default.isReachable else { return }
        Task {
            for command in await queue.drain() {
                guard let data = try? JSONEncoder().encode(command) else { continue }
                WCSession.default.sendMessage(["command": data], replyHandler: nil)
            }
        }
    }
}
