import Foundation
import MoveCore

public enum MoveNotificationContent {
    public static let categoryIdentifier = "MOVE_REMINDER"
    public static let doneAction = "DONE"
    public static let snoozeAction = "SNOOZE"
    public static let skipAction = "SKIP"

    public static func userInfo(for reminder: PlannedReminder) -> [String: String] {
        var info = ["exerciseID": reminder.exerciseID, "reminderID": reminder.id, "kind": reminder.kind.rawValue]
        if let targetAmount = reminder.targetAmount { info["targetAmount"] = String(targetAmount) }
        return info
    }
}
