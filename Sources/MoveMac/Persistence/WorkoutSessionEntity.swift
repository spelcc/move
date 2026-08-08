import Foundation
import SwiftData
import MoveCore

@Model final class WorkoutSessionEntity {
    var id: UUID
    var workoutID: UUID
    var workoutName: String
    var stepIndex: Int
    var round: Int
    var secondsRemaining: Int
    var plannedDurationSeconds: Int = 0
    var stateRaw: String
    var startedAt: Date
    var updatedAt: Date

    init(workout: WorkoutTemplate, stepIndex: Int = 0, round: Int = 1, secondsRemaining: Int = 0,
         state: WorkoutRunnerState = .preparing) {
        id = UUID(); workoutID = workout.id; workoutName = workout.name; self.stepIndex = stepIndex
        self.round = round; self.secondsRemaining = secondsRemaining; stateRaw = state.rawValue
        plannedDurationSeconds = workout.estimatedDuration
        startedAt = .now; updatedAt = .now
    }
}
