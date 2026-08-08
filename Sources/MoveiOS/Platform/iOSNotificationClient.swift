import Foundation
import UserNotifications
import MoveCore
import MoveShared

final class iOSNotificationClient: NSObject, @unchecked Sendable, NotificationClient {
    private let center = UNUserNotificationCenter.current()
    private let exercises: [String: Exercise]

    init(exercises: [Exercise] = []) {
        self.exercises = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }
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
            let exercise = exercises[reminder.exerciseID] ?? ExerciseLibrary.all.first { $0.id == reminder.exerciseID }
            let content = UNMutableNotificationContent()
            content.title = (exercise?.emoji ?? "💪") + " " + (exercise?.name ?? "Bouger")
            content.subtitle = "Pause mouvement"
            content.body = exercise.map { String($0.defaultAmount) + " " + metricLabel($0.metric) + " — touche pour ouvrir les actions" } ?? "Il est temps de bouger"
            content.categoryIdentifier = MoveNotificationContent.categoryIdentifier
            content.userInfo = MoveNotificationContent.userInfo(for: reminder)
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: reminder.fireDate)
            try await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
        }
    }
    private func metricLabel(_ metric: ExerciseMetric) -> String {
        switch metric { case .repetitions: return "répétitions"; case .seconds: return "secondes"; case .minutes: return "minutes"; case .free: return "à ton rythme" }
    }
    func remove(ids: [String]) async { center.removePendingNotificationRequests(withIdentifiers: ids) }
}
