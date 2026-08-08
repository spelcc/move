import Foundation
import UserNotifications
import MoveCore
import MoveShared

final class iOSNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound] }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        let exerciseID = info["exerciseID"] as? String
        let exercise = exerciseID.flatMap { id in ExerciseLibrary.all.first { $0.id == id } }
        let action = response.actionIdentifier
        if let exercise, action == MoveNotificationContent.doneAction || action == MoveNotificationContent.skipAction {
            let status: ActivityStatus = action == MoveNotificationContent.doneAction ? .completed : .skipped
            HistoryStore.append(.init(exerciseID: exercise.id, amount: status == .completed ? exercise.defaultAmount : 0, metric: exercise.metric, status: status, source: .hourly))
        } else if let exercise, action == MoveNotificationContent.snoozeAction {
            HistoryStore.append(.init(exerciseID: exercise.id, amount: 0, metric: exercise.metric, status: .snoozed, source: .hourly))
            let content = UNMutableNotificationContent()
            content.title = exercise.emoji + " " + exercise.name
            content.subtitle = "Rappel reporté"
            content.body = String(exercise.defaultAmount) + " — touche pour ouvrir les actions"
            content.categoryIdentifier = MoveNotificationContent.categoryIdentifier
            content.userInfo = info
            let date = Date().addingTimeInterval(15 * 60)
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            try? await center.add(UNNotificationRequest(identifier: "move.snoozed.\(Int(date.timeIntervalSince1970)).\(exercise.id)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
        }
        if action == UNNotificationDefaultActionIdentifier {
            NotificationCenter.default.post(name: .moveiOSNotificationAction, object: action, userInfo: info)
        }
    }
}

extension Notification.Name { static let moveiOSNotificationAction = Notification.Name("Move.iOS.notificationAction") }
