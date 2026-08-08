import Foundation

public enum WatchCommandAction: String, Codable, Sendable { case done, snooze, skip }
public struct WatchCommand: Codable, Equatable, Sendable {
    public let commandID: UUID
    public let action: WatchCommandAction
    public let reminderID: String?
    public init(commandID: UUID = UUID(), action: WatchCommandAction, reminderID: String? = nil) { self.commandID = commandID; self.action = action; self.reminderID = reminderID }
}

public actor WatchCommandQueue {
    private var queued: [WatchCommand] = []
    private var handled = Set<UUID>()
    public init() {}
    public func enqueue(_ command: WatchCommand) { guard !handled.contains(command.commandID), !queued.contains(where: { $0.commandID == command.commandID }) else { return }; queued.append(command) }
    public func drain() -> [WatchCommand] { let result = queued; queued.removeAll(); result.forEach { handled.insert($0.commandID) }; return result }
}
