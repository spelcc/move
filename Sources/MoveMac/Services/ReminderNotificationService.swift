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
        let done = UNNotificationAction(identifier: "DONE", title: MoveCopy.text("notification.done"))
        let snooze = UNNotificationAction(identifier: "SNOOZE", title: MoveCopy.text("notification.snooze"))
        let skip = UNNotificationAction(identifier: "SKIP", title: MoveCopy.text("notification.skip"), options: [.destructive])
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: category, actions: [done, snooze, skip], intentIdentifiers: [])
        ])
    }

    static func deferNotification(_ notification: UNNotification, after delay: TimeInterval = 15 * 60) {
        guard notification.request.content.userInfo["deferred"] as? Bool != true else { return }
        let content = UNMutableNotificationContent()
        content.title = notification.request.content.title
        content.subtitle = notification.request.content.subtitle
        content.body = notification.request.content.body
        content.categoryIdentifier = category
        var userInfo = notification.request.content.userInfo
        userInfo["deferred"] = true
        content.userInfo = userInfo
        if notification.request.content.sound != nil { content.sound = .default }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, delay), repeats: false)
        let request = UNNotificationRequest(identifier: "move-deferred-\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { MoveLogger.notifications.error("Deferred reminder failed: \(String(describing: error), privacy: .public)") }
            else { MoveLogger.notifications.debug("Reminder deferred") }
        }
    }
}

final class MoveNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let preferences = (try? JSONDecoder().decode(ReminderPreferences.self, from: UserDefaults.standard.data(forKey: "move.reminderPreferences") ?? Data())) ?? ReminderPreferences()
        guard ReminderDeliveryPolicy.shouldDeliver(
            isFullScreen: ReminderContextDetector.isFullScreen,
            isMeeting: ReminderContextDetector.isMeeting,
            preferences: preferences
        ) else {
            ReminderNotificationService.deferNotification(notification)
            return []
        }
        return notification.request.content.userInfo["soundEnabled"] as? Bool == true ? [.banner, .sound] : [.banner]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        NotificationCenter.default.post(name: .moveNotificationAction, object: response.actionIdentifier,
                                        userInfo: response.notification.request.content.userInfo)
    }
}

extension Notification.Name {
    static let moveNotificationAction = Notification.Name("Move.notificationAction")
}
