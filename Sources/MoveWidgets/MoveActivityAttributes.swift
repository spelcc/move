import ActivityKit
import Foundation

public struct MoveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var exerciseName: String
        public var step: Int
        public var totalSteps: Int
        public var endDate: Date
        public init(exerciseName: String, step: Int, totalSteps: Int, endDate: Date) { self.exerciseName = exerciseName; self.step = step; self.totalSteps = totalSteps; self.endDate = endDate }
    }
    public var workoutID: String
    public init(workoutID: String) { self.workoutID = workoutID }
}
