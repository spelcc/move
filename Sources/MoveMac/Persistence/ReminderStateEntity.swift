import Foundation
import SwiftData
import MoveCore

@Model final class ReminderStateEntity {
    @Attribute(.unique) var id: String
    var nextReminderAt: Date?
    var lastReminderAt: Date?
    var lastUserInteractionAt: Date?
    var pausedUntil: Date?
    var updatedAt: Date

    init(state: ReminderState = .init()) {
        id = "reminder-state"; nextReminderAt = state.nextReminderAt; lastReminderAt = state.lastReminderAt
        lastUserInteractionAt = state.lastUserInteractionAt; pausedUntil = state.pausedUntil; updatedAt = .now
    }

    var state: ReminderState { .init(nextReminderAt: nextReminderAt, lastReminderAt: lastReminderAt, lastUserInteractionAt: lastUserInteractionAt, pausedUntil: pausedUntil) }
}
