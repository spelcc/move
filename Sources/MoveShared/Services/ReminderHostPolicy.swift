import Foundation
import MoveCore

public enum ReminderHostPolicy {
    public static func shouldSchedule(on host: ReminderHostPreference, platform: Platform) -> Bool {
        switch host {
        case .all: return true
        case .mac: return platform == .mac
        case .phoneAndWatch: return platform == .phone
        }
    }
    public enum Platform: Sendable { case mac, phone, watch }
}
