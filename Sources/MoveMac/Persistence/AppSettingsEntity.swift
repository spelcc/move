import Foundation
import SwiftData
import MoveCore

@Model final class AppSettingsEntity {
    @Attribute(.unique) var id: String
    var reminderData: Data
    var movementData: Data
    var updatedAt: Date

    init(reminder: ReminderPreferences = .init(), movement: MovementPreferences = .init()) {
        id = "settings"
        reminderData = (try? JSONEncoder().encode(reminder)) ?? Data()
        movementData = (try? JSONEncoder().encode(movement)) ?? Data()
        updatedAt = .now
    }

    func values() -> (ReminderPreferences, MovementPreferences) {
        let reminder = (try? JSONDecoder().decode(ReminderPreferences.self, from: reminderData)) ?? .init()
        let movement = (try? JSONDecoder().decode(MovementPreferences.self, from: movementData)) ?? .init()
        return (reminder, movement)
    }
}
