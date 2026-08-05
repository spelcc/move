import Foundation
import MoveCore

public struct PendingNotification: Equatable, Sendable {
    public let id: String
    public let fireDate: Date
    public init(id: String, fireDate: Date) { self.id = id; self.fireDate = fireDate }
}

public protocol NotificationClient: Sendable {
    func requestAuthorization() async throws -> Bool
    func pending() async -> [PendingNotification]
    func schedule(_ reminders: [PlannedReminder]) async throws
    func remove(ids: [String]) async
}
