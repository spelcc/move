import Foundation
import Observation
import SwiftData
import UserNotifications
import MoveCore
import MoveShared

enum iOSAppRoute: Equatable {
    case today(exerciseID: String?)
}

enum iOSNotificationRouting {
    static func route(for intent: iOSNotificationIntent, validExerciseIDs: Set<String>) -> iOSAppRoute? {
        guard intent.actionIdentifier == UNNotificationDefaultActionIdentifier else { return nil }
        let validID = intent.exerciseID.flatMap { validExerciseIDs.contains($0) ? $0 : nil }
        return .today(exerciseID: validID)
    }
}

@MainActor @Observable final class iOSAppStore {
    var reminder = ReminderPreferences()
    var movement = MovementPreferences()
    var appearance = AppearancePreferences()
    var reminderHost = ReminderHostPreference.phoneAndWatch
    var reminderState = ReminderState()
    var pendingRoute: iOSAppRoute?
    var notificationStatus: UNAuthorizationStatus = .notDetermined
    var schedulingError: String?
    let workout: iOSWorkoutController

    private let context: ModelContext
    private let coordinator: iOSReminderCoordinator
    private var reconcileTask: Task<Void, Never>?

    init(context: ModelContext, coordinator: iOSReminderCoordinator = .init()) {
        self.context = context
        self.coordinator = coordinator
        workout = iOSWorkoutController(context: context)
        loadPersistedState()
        migrateLegacyiOSDataIfNeeded()
    }

    var allExercises: [Exercise] {
        ExerciseLibrary.all + customExerciseEntities.compactMap(\.exercise)
    }

    var availableExercises: [Exercise] {
        ExerciseSelector().candidates(from: allExercises, preferences: movement)
    }

    var customExerciseEntities: [CustomExerciseEntity] {
        let descriptor = FetchDescriptor<CustomExerciseEntity>(
            predicate: #Predicate { !$0.archived },
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func exercise(withID id: String?) -> Exercise? {
        guard let id else { return nil }
        return allExercises.first { $0.id == id }
    }

    func persistSettings() {
        let settings = settingsEntity()
        settings.reminderData = (try? JSONEncoder().encode(reminder)) ?? Data()
        settings.movementData = (try? JSONEncoder().encode(movement)) ?? Data()
        settings.appearanceData = (try? JSONEncoder().encode(appearance)) ?? Data()
        settings.reminderHostRaw = reminderHost.rawValue
        settings.updatedAt = .now
        try? context.save()
        scheduleReminders()
    }

    func scheduleReminders(debounce: Duration = .milliseconds(250)) {
        reconcileTask?.cancel()
        let preferences = reminder
        let state = reminderState
        let host = reminderHost
        let exercises = availableExercises
        reconcileTask = Task { [weak self] in
            if debounce > .zero { try? await Task.sleep(for: debounce) }
            guard !Task.isCancelled, let self else { return }
            let result = await coordinator.reconcile(
                preferences: preferences,
                state: state,
                host: host,
                exercises: exercises
            )
            guard !Task.isCancelled else { return }
            notificationStatus = result.authorizationStatus
            schedulingError = result.errorDescription
            reminderState.nextReminderAt = result.nextReminderAt
            persistReminderState()
        }
    }

    func requestNotifications() async -> Bool {
        let granted = await coordinator.requestAuthorization()
        scheduleReminders(debounce: .zero)
        return granted
    }

    func record(
        exercise: Exercise,
        status: ActivityStatus,
        source: ActivitySource = .hourly,
        workoutID: UUID? = nil,
        amount: Int? = nil,
        metric: ExerciseMetric? = nil
    ) {
        context.insert(ActivityEntity(record: .init(
            exerciseID: exercise.id,
            amount: amount ?? (status == .completed ? exercise.defaultAmount : 0),
            metric: metric ?? exercise.metric,
            status: status,
            source: source,
            workoutID: workoutID
        )))
        reminderState.lastUserInteractionAt = .now
        reminderState.lastReminderAt = reminderState.nextReminderAt
        try? context.save()
    }

    func snooze(_ exercise: Exercise) {
        record(exercise: exercise, status: .snoozed)
        reminderState.snoozedReminderAt = .now.addingTimeInterval(TimeInterval(reminder.snoozeMinutes * 60))
        reminderState.snoozedExerciseID = exercise.id
        persistReminderState()
        scheduleReminders(debounce: .zero)
    }

    func handle(_ intent: iOSNotificationIntent) {
        let exercise = exercise(withID: intent.exerciseID)
        switch intent.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            pendingRoute = iOSNotificationRouting.route(
                for: intent,
                validExerciseIDs: Set(allExercises.map(\.id))
            )
        case MoveNotificationContent.doneAction:
            if let exercise { record(exercise: exercise, status: .completed) }
            scheduleReminders(debounce: .zero)
        case MoveNotificationContent.skipAction:
            if let exercise { record(exercise: exercise, status: .skipped) }
            scheduleReminders(debounce: .zero)
        case MoveNotificationContent.snoozeAction:
            if let exercise {
                snooze(exercise)
            }
        default:
            break
        }
    }

    func consumePendingRoute() -> iOSAppRoute? {
        defer { pendingRoute = nil }
        return pendingRoute
    }

    private func settingsEntity() -> AppSettingsEntity {
        if let existing = (try? context.fetch(FetchDescriptor<AppSettingsEntity>()))?.first {
            return existing
        }
        let settings = AppSettingsEntity(reminderHost: .phoneAndWatch)
        context.insert(settings)
        return settings
    }

    private func loadPersistedState() {
        if let settings = (try? context.fetch(FetchDescriptor<AppSettingsEntity>()))?.first {
            let values = settings.values()
            reminder = values.0
            movement = values.1
            appearance = values.2
            reminderHost = settings.reminderHost
        }
        if let saved = (try? context.fetch(FetchDescriptor<ReminderStateEntity>()))?.first {
            reminderState = saved.state
        }
    }

    private func persistReminderState() {
        let entity = (try? context.fetch(FetchDescriptor<ReminderStateEntity>()))?.first
            ?? ReminderStateEntity(state: reminderState)
        entity.nextReminderAt = reminderState.nextReminderAt
        entity.lastReminderAt = reminderState.lastReminderAt
        entity.lastUserInteractionAt = reminderState.lastUserInteractionAt
        entity.pausedUntil = reminderState.pausedUntil
        entity.snoozedReminderAt = reminderState.snoozedReminderAt
        entity.snoozedExerciseID = reminderState.snoozedExerciseID
        entity.updatedAt = .now
        if entity.modelContext == nil { context.insert(entity) }
        try? context.save()
    }

    private func migrateLegacyiOSDataIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "move.sharedPersistenceMigrationCompleted") else { return }

        if let data = defaults.data(forKey: "move.activityRecords"),
           let records = try? JSONDecoder().decode([ActivityRecord].self, from: data) {
            let existingIDs = Set(((try? context.fetch(FetchDescriptor<ActivityEntity>())) ?? []).map(\.id))
            for record in records where !existingIDs.contains(record.id) {
                context.insert(ActivityEntity(record: record))
            }
        }

        if defaults.object(forKey: "move.reminders.enabled") != nil {
            reminder.enabled = defaults.bool(forKey: "move.reminders.enabled")
            reminder.intervalMinutes = defaults.object(forKey: "move.reminders.intervalMinutes") as? Int ?? 60
            reminder.activeStartHour = defaults.object(forKey: "move.reminders.startHour") as? Int ?? 9
            reminder.activeEndHour = defaults.object(forKey: "move.reminders.endHour") as? Int ?? 19
            reminder.snoozeMinutes = defaults.object(forKey: "move.reminders.snoozeMinutes") as? Int ?? 15
            reminderHost = ReminderHostPreference(rawValue: defaults.string(forKey: "move.reminders.host") ?? "") ?? .phoneAndWatch
            persistSettings()
        }

        defaults.set(true, forKey: "move.sharedPersistenceMigrationCompleted")
        try? context.save()
    }
}
