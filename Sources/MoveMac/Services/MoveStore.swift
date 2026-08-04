import Foundation
import Observation
import SwiftData
import UserNotifications
import MoveCore

@MainActor @Observable final class MoveStore {
    var currentExercise: Exercise = ExerciseLibrary.builtIn.first!
    var isExpanded = false
    var selectedTab = "Aujourd’hui"
    var reminder = ReminderPreferences()
    var movement = MovementPreferences()
    var activeWorkout: WorkoutTemplate?
    var workoutStepIndex = 0
    var workoutRound = 1
    var secondsRemaining = 0
    var workoutState: WorkoutRunnerState = .preparing
    var resumableWorkout: WorkoutSessionEntity?
    private var timer: Timer?
    private let selector = ExerciseSelector()
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        if let saved = try? context.fetch(FetchDescriptor<AppSettingsEntity>()), let settings = saved.first {
            let values = settings.values(); reminder = values.0; movement = values.1
        }
        resumableWorkout = (try? context.fetch(FetchDescriptor<WorkoutSessionEntity>()))?.first
        chooseNext()
    }

    func persistSettings() {
        let existing = (try? context.fetch(FetchDescriptor<AppSettingsEntity>()))?.first
        let settings = existing ?? AppSettingsEntity()
        settings.reminderData = (try? JSONEncoder().encode(reminder)) ?? Data()
        settings.movementData = (try? JSONEncoder().encode(movement)) ?? Data()
        settings.updatedAt = .now
        if existing == nil { context.insert(settings) }
        try? context.save()
    }

    func chooseNext() { currentExercise = selector.next(from: ExerciseLibrary.builtIn, preferences: movement, recentExerciseIDs: []) ?? ExerciseLibrary.builtIn[0]; persistSettings() }
    func completeCurrent(source: ActivitySource = .hourly) {
        context.insert(ActivityEntity(record: .init(exerciseID: currentExercise.id, amount: currentExercise.defaultAmount, metric: currentExercise.metric, status: .completed, source: source)))
        try? context.save(); isExpanded = false; chooseNext()
    }
    func skipCurrent() {
        context.insert(ActivityEntity(record: .init(exerciseID: currentExercise.id, amount: currentExercise.defaultAmount, metric: currentExercise.metric, status: .skipped, source: .hourly)))
        try? context.save(); isExpanded = false; chooseNext()
    }

    func snoozeCurrent(for minutes: Int = 15) {
        context.insert(ActivityEntity(record: .init(exerciseID: currentExercise.id, amount: currentExercise.defaultAmount, metric: currentExercise.metric, status: .snoozed, source: .hourly)))
        try? context.save(); isExpanded = false; chooseNext()
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
    func addTenSeconds() { secondsRemaining += 10 }
    func advanceWorkout() {
        guard let workout = activeWorkout else { return }
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
