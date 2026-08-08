import Foundation
import MoveCore

public struct SyncedSettingsSnapshot: Equatable, Sendable {
    public let id: String
    public let updatedAt: Date
    public let reminder: ReminderPreferences
    public let movement: MovementPreferences
    public let appearance: AppearancePreferences
    public init(id: String = "settings", updatedAt: Date, reminder: ReminderPreferences, movement: MovementPreferences, appearance: AppearancePreferences) { self.id = id; self.updatedAt = updatedAt; self.reminder = reminder; self.movement = movement; self.appearance = appearance }
}

public enum ConflictResolver {
    public static func newestSettings(_ snapshots: [SyncedSettingsSnapshot]) -> SyncedSettingsSnapshot? {
        snapshots.max { lhs, rhs in lhs.updatedAt == rhs.updatedAt ? lhs.id < rhs.id : lhs.updatedAt < rhs.updatedAt }
    }

    public static func deduplicatedActivities(_ records: [ActivityRecord]) -> [ActivityRecord] {
        var newest: [UUID: ActivityRecord] = [:]
        for record in records {
            guard let previous = newest[record.id] else { newest[record.id] = record; continue }
            if record.performedAt >= previous.performedAt { newest[record.id] = record }
        }
        return newest.values.sorted { $0.performedAt < $1.performedAt }
    }
}
