import Foundation
import Observation
import SwiftData
import MoveCore
import MoveShared

@MainActor @Observable final class iOSWorkoutController {
    var activeWorkout: WorkoutTemplate?
    var completedWorkout: WorkoutTemplate?
    var stepIndex = 0
    var round = 1
    var secondsRemaining = 0
    var state = WorkoutRunnerState.preparing
    var finalRecoveryActive = false
    var resumableSession: WorkoutSessionEntity?

    private let context: ModelContext
    private var timer: Timer?
    private var timerDeadline: Date?
    private var stateBeforePause = WorkoutRunnerState.working
    private var preparationConsumed = false

    init(context: ModelContext) {
        self.context = context
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSessionEntity>())) ?? []
        resumableSession = sessions
            .filter { $0.stateRaw != "completed" && $0.stateRaw != "cancelled" }
            .max { $0.updatedAt < $1.updatedAt }
    }

    var currentStep: WorkoutStep? {
        guard let activeWorkout, activeWorkout.steps.indices.contains(stepIndex) else { return nil }
        return activeWorkout.steps[stepIndex]
    }

    var currentExercise: Exercise? {
        guard let id = currentStep?.exerciseID else { return nil }
        if let builtIn = ExerciseLibrary.all.first(where: { $0.id == id }) { return builtIn }
        let custom = (try? context.fetch(FetchDescriptor<CustomExerciseEntity>())) ?? []
        return custom.first { $0.id == id && !$0.archived }?.exercise
    }

    var resumableWorkout: WorkoutTemplate? {
        guard let session = resumableSession else { return nil }
        return ExerciseLibrary.quickWorkouts.first { $0.id == session.workoutID }
    }

    func start(_ workout: WorkoutTemplate) {
        guard workout.validationError == nil else { return }
        timer?.invalidate()
        completedWorkout = nil
        activeWorkout = workout
        stepIndex = 0
        round = 1
        finalRecoveryActive = false
        preparationConsumed = false
        stateBeforePause = .working
        resumableSession = nil
        beginStep()
    }

    func resume() {
        guard let session = resumableSession,
              let workout = resumableWorkout,
              let savedState = WorkoutRunnerState(rawValue: session.stateRaw) else { return }
        activeWorkout = workout
        stepIndex = min(session.stepIndex, max(0, workout.steps.count - 1))
        round = max(1, session.round)
        secondsRemaining = max(0, session.secondsRemaining)
        state = savedState
        stateBeforePause = .working
        finalRecoveryActive = state == .roundRest && round > workout.rounds
        preparationConsumed = state != .preparing
        if state != .paused { startTimer() }
    }

    func togglePause() {
        guard activeWorkout != nil else { return }
        if state == .paused {
            state = stateBeforePause
            startTimer()
        } else {
            stateBeforePause = state
            state = .paused
            timer?.invalidate()
        }
        saveProgress()
    }

    func pauseIfRunning() {
        guard activeWorkout != nil, state != .paused, state != .completed, state != .cancelled else { return }
        togglePause()
    }

    func completeRepetitionStep() {
        guard activeWorkout?.mode == .repetitions, state == .working else { return }
        finishStep(status: .completed)
    }

    func skipStep() {
        guard state == .working || state == .resting else { return }
        finishStep(status: .skipped)
    }

    func addTenSeconds() {
        secondsRemaining += 10
        if state != .paused { timerDeadline = .now.addingTimeInterval(TimeInterval(secondsRemaining)) }
        saveProgress()
    }

    func subtractTenSeconds() {
        secondsRemaining = max(0, secondsRemaining - 10)
        if state != .paused { timerDeadline = .now.addingTimeInterval(TimeInterval(secondsRemaining)) }
        saveProgress()
    }

    func cancel() {
        timer?.invalidate()
        timerDeadline = nil
        state = .cancelled
        if let session = resumableSession {
            session.stateRaw = WorkoutRunnerState.cancelled.rawValue
            session.updatedAt = .now
        }
        try? context.save()
        activeWorkout = nil
        completedWorkout = nil
        resumableSession = nil
    }

    func dismissCompletion() {
        completedWorkout = nil
    }

    func tick() {
        guard activeWorkout != nil, state != .paused else { return }
        if let timerDeadline {
            secondsRemaining = max(0, Int(ceil(timerDeadline.timeIntervalSinceNow)))
        }
        if secondsRemaining > 0 {
            saveProgress()
            return
        }
        self.timerDeadline = nil
        switch state {
        case .preparing:
            beginWork()
        case .working:
            enterRestOrFinishStep()
        case .resting:
            finishStep(status: .completed)
        case .roundRest:
            finalRecoveryActive ? completeWorkout() : beginWork()
        default:
            break
        }
    }

    private func beginStep() {
        guard let workout = activeWorkout else { return }
        if !preparationConsumed, workout.preparationSeconds > 0 {
            preparationConsumed = true
            state = .preparing
            secondsRemaining = workout.preparationSeconds
            startTimer()
            saveProgress()
        } else {
            beginWork()
        }
    }

    private func beginWork() {
        guard let step = currentStep else { return }
        state = .working
        secondsRemaining = step.workSeconds
        if activeWorkout?.mode != .repetitions { startTimer() }
        else { timer?.invalidate() }
        saveProgress()
    }

    private func enterRestOrFinishStep() {
        guard let step = currentStep else { return }
        if step.restSeconds > 0 {
            state = .resting
            secondsRemaining = step.restSeconds
            startTimer()
            saveProgress()
        } else {
            finishStep(status: .completed)
        }
    }

    private func finishStep(status: ActivityStatus) {
        guard let workout = activeWorkout, let step = currentStep else { return }
        let exercise = currentExercise
        let metric: ExerciseMetric = workout.mode == .repetitions
            ? .repetitions
            : (exercise?.metric == .minutes ? .minutes : .seconds)
        let amount = workout.mode == .repetitions ? step.workSeconds : max(1, step.workSeconds)
        let record = ActivityRecord(
            exerciseID: step.exerciseID,
            amount: status == .completed ? amount : 0,
            metric: metric,
            status: status,
            source: workout.mode == .free ? .freeMovement : .quickWorkout,
            workoutID: workout.id
        )
        context.insert(ActivityEntity(record: record))
        if let session = resumableSession {
            context.insert(WorkoutStepResultEntity(
                sessionID: session.id,
                stepID: step.id,
                exerciseID: step.exerciseID,
                round: round,
                status: status,
                amount: record.amount,
                durationSeconds: workout.mode == .repetitions ? 0 : step.workSeconds
            ))
        }

        stepIndex += 1
        if stepIndex >= workout.steps.count {
            stepIndex = 0
            round += 1
            if round <= workout.rounds, workout.roundRestSeconds > 0 {
                state = .roundRest
                secondsRemaining = workout.roundRestSeconds
                startTimer()
                saveProgress()
                return
            }
        }
        if round > workout.rounds {
            if workout.finalRecoverySeconds > 0 {
                finalRecoveryActive = true
                state = .roundRest
                secondsRemaining = workout.finalRecoverySeconds
                startTimer()
                saveProgress()
            } else {
                completeWorkout()
            }
            return
        }
        beginWork()
    }

    private func completeWorkout() {
        guard let workout = activeWorkout else { return }
        timer?.invalidate()
        state = .completed
        completedWorkout = workout
        if let session = resumableSession {
            session.stateRaw = WorkoutRunnerState.completed.rawValue
            session.updatedAt = .now
        }
        try? context.save()
        activeWorkout = nil
        resumableSession = nil
        finalRecoveryActive = false
    }

    private func startTimer() {
        timer?.invalidate()
        timerDeadline = .now.addingTimeInterval(TimeInterval(secondsRemaining))
        timer = .scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    private func saveProgress() {
        guard let workout = activeWorkout else { return }
        let session = resumableSession ?? WorkoutSessionEntity(workout: workout)
        session.workoutID = workout.id
        session.workoutName = workout.name
        session.stepIndex = stepIndex
        session.round = round
        session.secondsRemaining = secondsRemaining
        session.stateRaw = state.rawValue
        session.updatedAt = .now
        if resumableSession == nil {
            context.insert(session)
            resumableSession = session
        }
        try? context.save()
    }
}
