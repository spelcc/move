import Foundation

public enum ExerciseCategory: String, Codable, CaseIterable, Sendable { case strength, cardio, mobility, stretch, recovery, free }
public enum ExerciseMetric: String, Codable, Sendable { case repetitions, seconds, minutes, free }
public enum ActivityStatus: String, Codable, Sendable { case proposed, completed, skipped, snoozed, replaced }
public enum ActivitySource: String, Codable, Sendable { case hourly, quickWorkout, customWorkout, freeMovement }

public struct Exercise: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var category: ExerciseCategory
    public var metric: ExerciseMetric
    public var defaultAmount: Int
    public var difficulty: Int
    public var equipment: Set<String>
    public var tags: Set<String>
    public var emoji: String
    public init(id: String, name: String, category: ExerciseCategory, metric: ExerciseMetric, defaultAmount: Int, difficulty: Int = 1, equipment: Set<String> = [], tags: Set<String> = [], emoji: String) {
        self.id = id; self.name = name; self.category = category; self.metric = metric; self.defaultAmount = defaultAmount; self.difficulty = difficulty; self.equipment = equipment; self.tags = tags; self.emoji = emoji
    }
}

public struct ActivityRecord: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let exerciseID: String
    public let performedAt: Date
    public let amount: Int
    public let metric: ExerciseMetric
    public let status: ActivityStatus
    public let source: ActivitySource
    public let workoutID: UUID?
    public init(id: UUID = UUID(), exerciseID: String, performedAt: Date = .now, amount: Int, metric: ExerciseMetric, status: ActivityStatus, source: ActivitySource, workoutID: UUID? = nil) {
        self.id = id; self.exerciseID = exerciseID; self.performedAt = performedAt; self.amount = amount; self.metric = metric; self.status = status; self.source = source; self.workoutID = workoutID
    }
}

public struct MovementPreferences: Codable, Sendable {
    public var disabledExerciseIDs: Set<String> = []
    public var availableEquipment: Set<String> = []
    public var excludedTags: Set<String> = []
    public var preferredDifficulty: ClosedRange<Int> = 1...3
    public init() {}
}

public struct ReminderPreferences: Codable, Sendable {
    public var intervalMinutes = 60
    public var activeStartHour = 9
    public var activeEndHour = 19
    public var enabledWeekdays: Set<Int> = [2, 3, 4, 5, 6]
    public var snoozeMinutes = 15
    public init() {}
}

public struct WorkoutStep: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var exerciseID: String
    public var workSeconds: Int
    public var restSeconds: Int
    public init(id: UUID = UUID(), exerciseID: String, workSeconds: Int = 40, restSeconds: Int = 20) { self.id = id; self.exerciseID = exerciseID; self.workSeconds = workSeconds; self.restSeconds = restSeconds }
}

public struct WorkoutTemplate: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var rounds: Int
    public var steps: [WorkoutStep]
    public init(id: UUID = UUID(), name: String, rounds: Int, steps: [WorkoutStep]) { self.id = id; self.name = name; self.rounds = rounds; self.steps = steps }
    public var estimatedDuration: Int { rounds * steps.reduce(0) { $0 + $1.workSeconds + $1.restSeconds } }
}
