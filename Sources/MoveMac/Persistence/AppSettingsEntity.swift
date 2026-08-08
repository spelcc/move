import Foundation
import SwiftData
import MoveCore

@Model final class AppSettingsEntity {
    var id: String
    var reminderData: Data
    var movementData: Data
    var appearanceData: Data
    var reminderHostRaw: String
    var updatedAt: Date

    init(reminder: ReminderPreferences = .init(), movement: MovementPreferences = .init(), appearance: AppearancePreferences = .init()) {
        id = "settings"
        reminderData = (try? JSONEncoder().encode(reminder)) ?? Data()
        movementData = (try? JSONEncoder().encode(movement)) ?? Data()
        appearanceData = (try? JSONEncoder().encode(appearance)) ?? Data()
        reminderHostRaw = ReminderHostPreference.phoneAndWatch.rawValue
        updatedAt = .now
    }

    func values() -> (ReminderPreferences, MovementPreferences, AppearancePreferences) {
        let reminder = (try? JSONDecoder().decode(ReminderPreferences.self, from: reminderData)) ?? .init()
        let movement = (try? JSONDecoder().decode(MovementPreferences.self, from: movementData)) ?? .init()
        let appearance = (try? JSONDecoder().decode(AppearancePreferences.self, from: appearanceData)) ?? .init()
        return (reminder, movement, appearance)
    }

    var reminderHost: ReminderHostPreference {
        get { ReminderHostPreference(rawValue: reminderHostRaw) ?? .phoneAndWatch }
        set { reminderHostRaw = newValue.rawValue; updatedAt = .now }
    }
}
