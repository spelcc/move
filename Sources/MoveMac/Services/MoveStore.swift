import Foundation
import AppKit
import Observation
import SwiftData
import UserNotifications
import MoveCore

@MainActor @Observable final class MoveStore {
    var currentExercise: Exercise = ExerciseLibrary.all.first!
    var panelState: NotchPanelState = .hidden
    var selectedTab = "Aujourd’hui"
    var reminder = ReminderPreferences()
    var reminderState = ReminderState()
    var movement = MovementPreferences()
    var noCompatibleExercises = false
    var appearance = AppearancePreferences()
    var activeWorkout: WorkoutTemplate?
    private var recentExerciseIDs: [String] = []
    var workoutStepIndex = 0
    var workoutRound = 1
    var secondsRemaining = 0
    var workoutState: WorkoutRunnerState = .preparing
    var resumableWorkout: WorkoutSessionEntity?
    private var timer: Timer?
    private let selector = ExerciseSelector()
    private let scheduler = ReminderScheduler()
    private let context: ModelContext
    private var notificationObserver: NSObjectProtocol?

    private var availableExercises: [Exercise] {
        let custom = (try? context.fetch(FetchDescriptor<CustomExerciseEntity>())) ?? []
        return ExerciseLibrary.all + custom.filter { !$0.archived }.compactMap(\.exercise)
    }

    func exercise(withID id: String) -> Exercise? {
        availableExercises.first { $0.id == id }
    }

    init(context: ModelContext) {
        self.context = context
        if let saved = try? context.fetch(FetchDescriptor<AppSettingsEntity>()), let settings = saved.first {
            let values = settings.values(); reminder = values.0; movement = values.1; appearance = values.2
        }
        resumableWorkout = (try? context.fetch(FetchDescriptor<WorkoutSessionEntity>()))?.first
        if let savedReminder = (try? context.fetch(FetchDescriptor<ReminderStateEntity>()))?.first { reminderState = savedReminder.state }
        chooseNext()
        scheduleNextReminder()
        notificationObserver = NotificationCenter.default.addObserver(forName: .moveNotificationAction, object: nil, queue: .main) { [weak self] note in
            guard let action = note.object as? String else { return }
            let exerciseID = note.userInfo?["exerciseID"] as? String
            Task { @MainActor in self?.handleNotificationAction(action, exerciseID: exerciseID) }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(60))
                self?.scheduleNextReminderAfterWake()
            }
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NSSystemClockDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.scheduleNextReminder() }
        }
    }

    func persistSettings() {
        let existing = (try? context.fetch(FetchDescriptor<AppSettingsEntity>()))?.first
        let settings = existing ?? AppSettingsEntity()
        settings.reminderData = (try? JSONEncoder().encode(reminder)) ?? Data()
        settings.movementData = (try? JSONEncoder().encode(movement)) ?? Data()
        settings.appearanceData = (try? JSONEncoder().encode(appearance)) ?? Data()
        settings.updatedAt = .now
        if existing == nil { context.insert(settings) }
        try? context.save()
    }

    func scheduleNextReminder(from now: Date = .now) {
        guard let next = scheduler.nextDate(now: now, preferences: reminder, state: reminderState) else { MoveLogger.scheduler.warning("No compatible reminder date") ; return }
        reminderState.nextReminderAt = next
        let entity = (try? context.fetch(FetchDescriptor<ReminderStateEntity>()))?.first ?? ReminderStateEntity(state: reminderState)
        entity.nextReminderAt = next; entity.updatedAt = .now
        if entity.modelContext == nil { context.insert(entity) }
        reminderState = entity.state
        try? context.save()
        ReminderNotificationService.cancelPending()
        Task {
            do { try await ReminderNotificationService.schedule(exercise: currentExercise, at: next, sound: appearance.sounds); MoveLogger.notifications.debug("Reminder scheduled") }
            catch { MoveLogger.notifications.error("Reminder scheduling failed: \(String(describing: error), privacy: .public)") }
        }
    }

    func scheduleNextReminderAfterWake(from now: Date = .now) {
        guard let next = scheduler.nextDateAfterWake(now: now, preferences: reminder, state: reminderState) else {
            MoveLogger.scheduler.warning("No compatible reminder date after wake")
            return
        }
        reminderState.nextReminderAt = next
        persistReminderState()
        ReminderNotificationService.cancelPending()
        Task { try? await ReminderNotificationService.schedule(exercise: currentExercise, at: next, sound: appearance.sounds) }
    }

    private func persistReminderState() {
        let entity = (try? context.fetch(FetchDescriptor<ReminderStateEntity>()))?.first ?? ReminderStateEntity(state: reminderState)
        entity.nextReminderAt = reminderState.nextReminderAt
        entity.lastReminderAt = reminderState.lastReminderAt
        entity.lastUserInteractionAt = reminderState.lastUserInteractionAt
        entity.pausedUntil = reminderState.pausedUntil
        entity.updatedAt = .now
        if entity.modelContext == nil { context.insert(entity) }
        try? context.save()
    }

    func pauseReminders(until date: Date) {
        reminderState.pausedUntil = date; reminderState.nextReminderAt = date
        let entity = (try? context.fetch(FetchDescriptor<ReminderStateEntity>()))?.first ?? ReminderStateEntity(state: reminderState)
        entity.pausedUntil = date; entity.nextReminderAt = date; entity.updatedAt = .now
        if entity.modelContext == nil { context.insert(entity) }
        try? context.save(); ReminderNotificationService.cancelPending(); scheduleNextReminder()
    }

    func chooseNext() {
        let next = selector.next(from: availableExercises, preferences: movement, recentExerciseIDs: recentExerciseIDs)
        noCompatibleExercises = next == nil
        if let next { currentExercise = next; recentExerciseIDs.append(next.id); recentExerciseIDs = Array(recentExerciseIDs.suffix(6)) }
        persistSettings()
    }
    func enableAllExercises() {
        movement.disabledExerciseIDs.removeAll()
        movement.excludedTags.removeAll()
        movement.availableEquipment.removeAll()
        persistSettings()
        chooseNext()
    }
    func completeCurrent(source: ActivitySource = .hourly) {
        context.insert(ActivityEntity(record: .init(exerciseID: currentExercise.id, amount: currentExercise.defaultAmount, metric: currentExercise.metric, status: .completed, source: source)))
        markReminderInteraction(); try? context.save(); panelState = .success; chooseNext(); scheduleNextReminder()
    }
    func skipCurrent() {
        context.insert(ActivityEntity(record: .init(exerciseID: currentExercise.id, amount: currentExercise.defaultAmount, metric: currentExercise.metric, status: .skipped, source: .hourly)))
        markReminderInteraction(); try? context.save(); panelState = .skipped; chooseNext(); scheduleNextReminder()
    }

    func snoozeCurrent(for minutes: Int = 15) {
        context.insert(ActivityEntity(record: .init(exerciseID: currentExercise.id, amount: currentExercise.defaultAmount, metric: currentExercise.metric, status: .snoozed, source: .hourly)))
        markReminderInteraction(); reminderState.pausedUntil = .now.addingTimeInterval(TimeInterval(minutes * 60))
        try? context.save(); panelState = .snooze; chooseNext(); ReminderNotificationService.cancelPending(); scheduleNextReminder()
    }

    private func markReminderInteraction() {
        reminderState.lastUserInteractionAt = .now
        reminderState.lastReminderAt = reminderState.nextReminderAt
        reminderState.pausedUntil = nil
        let entity = (try? context.fetch(FetchDescriptor<ReminderStateEntity>()))?.first ?? ReminderStateEntity(state: reminderState)
        entity.lastUserInteractionAt = reminderState.lastUserInteractionAt; entity.lastReminderAt = reminderState.lastReminderAt; entity.pausedUntil = nil; entity.updatedAt = .now
        if entity.modelContext == nil { context.insert(entity) }
    }

    private func handleNotificationAction(_ action: String, exerciseID: String?) {
        if let exerciseID, let exercise = availableExercises.first(where: { $0.id == exerciseID }) { currentExercise = exercise }
        switch action {
        case "DONE": completeCurrent()
        case "SKIP": skipCurrent()
        case "SNOOZE": snoozeCurrent(for: reminder.snoozeMinutes)
        default: break
        }
    }
    func start(_ workout: WorkoutTemplate) {
        guard workout.validationError == nil else { return }
        activeWorkout = workout; workoutStepIndex = 0; workoutRound = 1; workoutState = .preparing; beginStep(); saveWorkoutProgress()
    }

    func resume(_ workout: WorkoutTemplate) {
        guard let saved = resumableWorkout, saved.workoutID == workout.id,
              let state = WorkoutRunnerState(rawValue: saved.stateRaw), state != .completed, state != .cancelled else { return }
        activeWorkout = workout; workoutStepIndex = min(saved.stepIndex, max(0, workout.steps.count - 1)); workoutRound = max(1, saved.round)
        secondsRemaining = max(0, saved.secondsRemaining); workoutState = state
        if workoutState != .paused {
            timer?.invalidate()
            timer = .scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
            saveWorkoutProgress()
        }
    }
    func beginStep() {
        guard let workout = activeWorkout else { return }
        workoutState = .working
        secondsRemaining = workout.steps[workoutStepIndex].workSeconds
        timer?.invalidate(); timer = .scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
        saveWorkoutProgress()
    }
    private func tick() { if secondsRemaining > 0 { secondsRemaining -= 1; saveWorkoutProgress() } else { advanceWorkout() } }
    func togglePause() {
        guard activeWorkout != nil else { return }
        if workoutState == .paused { beginStep() } else { workoutState = .paused; timer?.invalidate(); saveWorkoutProgress() }
    }
    func addTenSeconds() { secondsRemaining += 10; saveWorkoutProgress() }
    func subtractTenSeconds() { secondsRemaining = max(0, secondsRemaining - 10); saveWorkoutProgress() }
    func previousWorkoutStep() {
        guard let workout = activeWorkout else { return }
        if workoutStepIndex > 0 {
            workoutStepIndex -= 1
        } else if workoutRound > 1 {
            workoutRound -= 1
            workoutStepIndex = workout.steps.count - 1
        } else {
            return
        }
        beginStep()
    }
    func skipWorkoutStep() { finishWorkoutStep(status: .skipped) }
    func advanceWorkout() {
        finishWorkoutStep(status: .completed)
    }

    private func finishWorkoutStep(status: ActivityStatus) {
        guard let workout = activeWorkout else { return }
        let finishedStep = workout.steps[workoutStepIndex]
        let exercise = exercise(withID: finishedStep.exerciseID)
        let metric: ExerciseMetric = workout.mode == .repetitions ? .repetitions : (exercise?.metric == .minutes ? .minutes : .seconds)
        let source: ActivitySource = workout.mode == .free ? .freeMovement : (ExerciseLibrary.quickWorkouts.contains(where: { $0.id == workout.id }) ? .quickWorkout : .customWorkout)
        context.insert(ActivityEntity(record: .init(exerciseID: finishedStep.exerciseID, amount: finishedStep.workSeconds, metric: metric, status: status, source: source, workoutID: workout.id)))
        try? context.save()
        workoutStepIndex += 1
        if workoutStepIndex >= workout.steps.count { workoutStepIndex = 0; workoutRound += 1 }
        if workoutRound > workout.rounds { timer?.invalidate(); workoutState = .completed; activeWorkout = nil; clearWorkoutProgress(); return }
        beginStep()
    }

    func cancelWorkout() { timer?.invalidate(); workoutState = .cancelled; activeWorkout = nil; clearWorkoutProgress() }

    private func saveWorkoutProgress() {
        guard let workout = activeWorkout else { return }
        let session = resumableWorkout ?? WorkoutSessionEntity(workout: workout)
        session.workoutID = workout.id; session.workoutName = workout.name; session.stepIndex = workoutStepIndex
        session.round = workoutRound; session.secondsRemaining = secondsRemaining; session.stateRaw = workoutState.rawValue; session.updatedAt = .now
        if resumableWorkout == nil { context.insert(session); resumableWorkout = session }
        try? context.save()
    }

    private func clearWorkoutProgress() {
        if let session = resumableWorkout { context.delete(session); resumableWorkout = nil; try? context.save() }
    }
    func requestNotifications() async { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
}
