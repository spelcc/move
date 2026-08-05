import Foundation
import UserNotifications

final class iOSNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound] }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        NotificationCenter.default.post(name: .moveiOSNotificationAction, object: response.actionIdentifier, userInfo: response.notification.request.content.userInfo)
    }
}

extension Notification.Name { static let moveiOSNotificationAction = Notification.Name("Move.iOS.notificationAction") }
