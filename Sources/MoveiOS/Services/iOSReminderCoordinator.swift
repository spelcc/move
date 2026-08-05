import Foundation
import MoveCore
import MoveShared

@MainActor final class iOSReminderCoordinator {
    private let client = iOSNotificationClient()
    private let planner = ReminderPlanner()
    private var preferences = ReminderPreferences()
    private var state = ReminderState()
    private var host = ReminderHostPreference.phoneAndWatch

    func reconcile(now: Date = .now) async {
        preferences.enabled = UserDefaults.standard.object(forKey: "move.reminders.enabled") as? Bool ?? true
        preferences.intervalMinutes = UserDefaults.standard.object(forKey: "move.reminders.intervalMinutes") as? Int ?? 60
        preferences.activeStartHour = UserDefaults.standard.object(forKey: "move.reminders.startHour") as? Int ?? 9
        preferences.activeEndHour = UserDefaults.standard.object(forKey: "move.reminders.endHour") as? Int ?? 19
        preferences.snoozeMinutes = UserDefaults.standard.object(forKey: "move.reminders.snoozeMinutes") as? Int ?? 15
        host = ReminderHostPreference(rawValue: UserDefaults.standard.string(forKey: "move.reminders.host") ?? "") ?? .phoneAndWatch
        guard ReminderHostPolicy.shouldSchedule(on: host, platform: .phone) else {
            let ids = await client.pending().map(\.id).filter { $0.hasPrefix("move.") }
            await client.remove(ids: ids)
            return
        }
        let horizon = Calendar.current.date(byAdding: .day, value: 14, to: now) ?? now.addingTimeInterval(14 * 86400)
        let plan = planner.plan(.init(now: now, horizon: horizon, maximumCount: 64, preferences: preferences, state: state, exercises: ExerciseLibrary.all))
        do {
            try await ReminderQueueReconciler(client: client).reconcile(plan: plan)
            state.nextReminderAt = plan.first?.fireDate
            UserDefaults.standard.set(state.nextReminderAt?.timeIntervalSince1970, forKey: "move.nextReminderAt")
            UserDefaults.standard.set(plan.count, forKey: "move.reminderQueueCount")
        }
        catch { NSLog("Move iOS reminder reconciliation failed: %@", String(describing: error)) }
    }

    func requestAuthorization() async -> Bool { (try? await client.requestAuthorization()) ?? false }
}
