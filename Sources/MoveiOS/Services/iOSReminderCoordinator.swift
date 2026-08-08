import Foundation
import UserNotifications
import MoveCore
import MoveShared

struct iOSReminderReconcileResult {
    let nextReminderAt: Date?
    let authorizationStatus: UNAuthorizationStatus
    let errorDescription: String?
}

@MainActor final class iOSReminderCoordinator {
    private let planner = ReminderPlanner()

    func reconcile(
        preferences: ReminderPreferences,
        state: ReminderState,
        host: ReminderHostPreference,
        exercises: [Exercise],
        now: Date = .now
    ) async -> iOSReminderReconcileResult {
        let client = iOSNotificationClient(exercises: exercises)
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        guard ReminderHostPolicy.shouldSchedule(on: host, platform: .phone), preferences.enabled else {
            let ids = await client.pending().map(\.id).filter { $0.hasPrefix("move.") }
            await client.remove(ids: ids)
            return .init(nextReminderAt: nil, authorizationStatus: status, errorDescription: nil)
        }

        let horizon = Calendar.current.date(byAdding: .day, value: 14, to: now)
            ?? now.addingTimeInterval(14 * 86_400)
        let plan = planner.plan(.init(
            now: now,
            horizon: horizon,
            maximumCount: 64,
            preferences: preferences,
            state: state,
            exercises: exercises
        ))
        do {
            try await ReminderQueueReconciler(client: client).reconcile(plan: plan)
            return .init(nextReminderAt: plan.first?.fireDate, authorizationStatus: status, errorDescription: nil)
        } catch {
            return .init(
                nextReminderAt: plan.first?.fireDate,
                authorizationStatus: status,
                errorDescription: String(describing: error)
            )
        }
    }

    func requestAuthorization() async -> Bool {
        (try? await iOSNotificationClient().requestAuthorization()) ?? false
    }
}
