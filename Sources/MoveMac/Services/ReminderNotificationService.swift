import Foundation
import AppKit
import UserNotifications
import MoveCore

enum ReminderContextDetector {
    private static let meetingBundleIDs: Set<String> = [
        "us.zoom.xos", "com.microsoft.teams2", "com.microsoft.teams", "com.cisco.webexmeetingsapp",
        "com.apple.FaceTime"
    ]

    static var isMeeting: Bool {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return false }
        return meetingBundleIDs.contains(bundleID)
    }

    static var isFullScreen: Bool {
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              frontmost.bundleIdentifier != Bundle.main.bundleIdentifier else { return false }
        return NSScreen.screens.contains { $0.frame.equalTo($0.visibleFrame) }
    }
}

enum ReminderNotificationService {
    static let category = "MOVE_REMINDER"

    static func configure() {
        let done = UNNotificationAction(identifier: "DONE", title: "Fait")
        let snooze = UNNotificationAction(identifier: "SNOOZE", title: "Reporter")
        let skip = UNNotificationAction(identifier: "SKIP", title: "Passer", options: [.destructive])
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: category, actions: [done, snooze, skip], intentIdentifiers: [])
        ])
    }

    static func schedule(exercise: Exercise, at date: Date, sound: SoundMode = .normal) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Move"
        content.body = "\(exercise.emoji) \(exercise.name) — \(exercise.defaultAmount)"
        content.categoryIdentifier = category
        content.userInfo = ["exerciseID": exercise.id, "soundEnabled": sound != .off]
        if sound != .off { content.sound = .default }
        let interval = max(1, date.timeIntervalSinceNow)
        let request = UNNotificationRequest(identifier: "move-reminder-\(exercise.id)-\(date.timeIntervalSince1970)", content: content,
                                             trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false))
        try await UNUserNotificationCenter.current().add(request)
    }

    static func cancelPending() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

final class MoveNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let preferences = (try? JSONDecoder().decode(ReminderPreferences.self, from: UserDefaults.standard.data(forKey: "move.reminderPreferences") ?? Data())) ?? ReminderPreferences()
        guard ReminderDeliveryPolicy.shouldDeliver(
            isFullScreen: ReminderContextDetector.isFullScreen,
            isMeeting: ReminderContextDetector.isMeeting,
            preferences: preferences
        ) else { return [] }
        notification.request.content.userInfo["soundEnabled"] as? Bool == true ? [.banner, .sound] : [.banner]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        NotificationCenter.default.post(name: .moveNotificationAction, object: response.actionIdentifier,
                                        userInfo: response.notification.request.content.userInfo)
    }
}

extension Notification.Name {
    static let moveNotificationAction = Notification.Name("Move.notificationAction")
}
