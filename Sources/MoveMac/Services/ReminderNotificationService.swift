import Foundation
import UserNotifications
import MoveCore

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

    static func schedule(exercise: Exercise, at date: Date) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Move"
        content.body = "(exercise.emoji) (exercise.name) — (exercise.defaultAmount)"
        content.categoryIdentifier = category
        content.userInfo = ["exerciseID": exercise.id]
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
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        NotificationCenter.default.post(name: .moveNotificationAction, object: response.actionIdentifier,
                                        userInfo: response.notification.request.content.userInfo)
    }
}

extension Notification.Name {
    static let moveNotificationAction = Notification.Name("Move.notificationAction")
}
