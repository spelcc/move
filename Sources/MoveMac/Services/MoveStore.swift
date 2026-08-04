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
    private var timer: Timer?
    private let selector = ExerciseSelector()
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        if let saved = try? context.fetch(FetchDescriptor<AppSettingsEntity>()), let settings = saved.first {
            let values = settings.values(); reminder = values.0; movement = values.1
        }
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
        activeWorkout = workout; workoutStepIndex = 0; workoutRound = 1; workoutState = .preparing; beginStep()
    }
    func beginStep() {
        guard let workout = activeWorkout else { return }
        workoutState = .working
        secondsRemaining = workout.steps[workoutStepIndex].workSeconds
        timer?.invalidate(); timer = .scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
    }
    private func tick() { if secondsRemaining > 0 { secondsRemaining -= 1 } else { advanceWorkout() } }
    func togglePause() {
        guard activeWorkout != nil else { return }
        if workoutState == .paused { beginStep() } else { workoutState = .paused; timer?.invalidate() }
    }
    func addTenSeconds() { secondsRemaining += 10 }
    func advanceWorkout() {
        guard let workout = activeWorkout else { return }
        workoutStepIndex += 1
        if workoutStepIndex >= workout.steps.count { workoutStepIndex = 0; workoutRound += 1 }
        if workoutRound > workout.rounds { timer?.invalidate(); workoutState = .completed; activeWorkout = nil; return }
        beginStep()
    }
    func requestNotifications() async { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
}
