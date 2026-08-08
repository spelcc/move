import Foundation
import UserNotifications
import MoveCore
import MoveShared

final class MacNotificationClient: NSObject, @unchecked Sendable, NotificationClient {
    private let center = UNUserNotificationCenter.current()
    private let exercises: [String: Exercise]
    private let sound: SoundMode

    init(exercises: [Exercise] = [], sound: SoundMode = .normal) {
        self.exercises = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
        self.sound = sound
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func pending() async -> [PendingNotification] {
        await center.pendingNotificationRequests().compactMap { request in
            guard request.identifier.hasPrefix("move.") else { return nil }
            let date: Date
            if let trigger = request.trigger as? UNCalendarNotificationTrigger,
               let scheduled = Calendar.current.date(from: trigger.dateComponents) {
                date = scheduled
            } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                date = .now.addingTimeInterval(trigger.timeInterval)
            } else {
                date = .now
            }
            return PendingNotification(id: request.identifier, fireDate: date)
        }
    }

    func schedule(_ reminders: [PlannedReminder]) async throws {
        for reminder in reminders {
            let exercise = exercises[reminder.exerciseID]
                ?? ExerciseLibrary.all.first { $0.id == reminder.exerciseID }
            let content = UNMutableNotificationContent()
            content.title = MoveCopy.text("notification.title")
            content.body = exercise.map { "\($0.emoji) \($0.displayName) — \($0.defaultAmount)" }
                ?? MoveCopy.text("notification.title")
            content.categoryIdentifier = ReminderNotificationService.category
            content.userInfo = MoveNotificationContent.userInfo(for: reminder)
            content.userInfo["soundEnabled"] = sound != .off
            if sound != .off { content.sound = .default }

            var components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: reminder.fireDate
            )
            components.timeZone = .current
            let request = UNNotificationRequest(
                identifier: reminder.id,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try await center.add(request)
        }
    }

    func remove(ids: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }
}

actor MacReminderScheduleQueue {
    static let shared = MacReminderScheduleQueue()

    struct Request: Sendable {
        let plan: [PlannedReminder]
        let exercises: [Exercise]
        let sound: SoundMode
    }

    private var latest: Request?
    private var running = false

    func submit(_ request: Request) async {
        latest = request
        guard !running else { return }
        running = true
        defer { running = false }

        while let request = latest {
            latest = nil
            do {
                let client = MacNotificationClient(exercises: request.exercises, sound: request.sound)
                try await ReminderQueueReconciler(client: client).reconcile(plan: request.plan)
                MoveLogger.notifications.debug("Reminder queue reconciled")
            } catch {
                MoveLogger.notifications.error(
                    "Reminder scheduling failed: \(String(describing: error), privacy: .public)"
                )
            }
        }
    }
}
