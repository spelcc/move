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
    private var timer: Timer?
    private let selector = ExerciseSelector()
    private let context: ModelContext

    init(context: ModelContext) { self.context = context; chooseNext() }

    func chooseNext() { currentExercise = selector.next(from: ExerciseLibrary.builtIn, preferences: movement, recentExerciseIDs: []) ?? ExerciseLibrary.builtIn[0] }
    func completeCurrent(source: ActivitySource = .hourly) {
        context.insert(ActivityEntity(record: .init(exerciseID: currentExercise.id, amount: currentExercise.defaultAmount, metric: currentExercise.metric, status: .completed, source: source)))
        try? context.save(); isExpanded = false; chooseNext()
    }
    func skipCurrent() {
        context.insert(ActivityEntity(record: .init(exerciseID: currentExercise.id, amount: currentExercise.defaultAmount, metric: currentExercise.metric, status: .skipped, source: .hourly)))
        try? context.save(); isExpanded = false; chooseNext()
    }
    func start(_ workout: WorkoutTemplate) { activeWorkout = workout; workoutStepIndex = 0; workoutRound = 1; beginStep() }
    func beginStep() {
        guard let workout = activeWorkout else { return }
        secondsRemaining = workout.steps[workoutStepIndex].workSeconds
        timer?.invalidate(); timer = .scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
    }
    private func tick() { if secondsRemaining > 0 { secondsRemaining -= 1 } else { advanceWorkout() } }
    func advanceWorkout() {
        guard let workout = activeWorkout else { return }
        workoutStepIndex += 1
        if workoutStepIndex >= workout.steps.count { workoutStepIndex = 0; workoutRound += 1 }
        if workoutRound > workout.rounds { timer?.invalidate(); activeWorkout = nil; return }
        beginStep()
    }
    func requestNotifications() async { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
}
