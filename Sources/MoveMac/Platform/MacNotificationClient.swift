import Foundation
import UserNotifications
import MoveCore
import MoveShared

final class MacNotificationClient: NSObject, @unchecked Sendable, NotificationClient {
    private let center = UNUserNotificationCenter.current()
    func requestAuthorization() async throws -> Bool { try await center.requestAuthorization(options: [.alert, .sound, .badge]) }
    func pending() async -> [PendingNotification] {
        let requests = await center.pendingNotificationRequests()
        return requests.compactMap { request in
            guard request.identifier.hasPrefix("move."), let trigger = request.trigger as? UNCalendarNotificationTrigger,
                  let date = Calendar.current.date(from: trigger.dateComponents) else { return nil }
            return PendingNotification(id: request.identifier, fireDate: date)
        }
    }
    func schedule(_ reminders: [PlannedReminder]) async throws {
        for reminder in reminders {
            var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.fireDate)
            components.timeZone = .current
            let content = UNMutableNotificationContent(); content.title = "Move"; content.body = "Il est temps de bouger"; content.userInfo = MoveNotificationContent.userInfo(for: reminder)
            let request = UNNotificationRequest(identifier: reminder.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            try await center.add(request)
        }
    }
    func remove(ids: [String]) async { center.removePendingNotificationRequests(withIdentifiers: ids) }
}
