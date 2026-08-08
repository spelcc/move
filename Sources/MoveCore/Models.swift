import Foundation

public enum ExerciseCategory: String, Codable, CaseIterable, Sendable { case strength, cardio, mobility, stretch, recovery, free }
public enum ExerciseMetric: String, Codable, Sendable { case repetitions, seconds, minutes, free }
public enum WorkoutMode: String, Codable, CaseIterable, Sendable { case interval, repetitions, circuit, emom, free }
public enum WorkoutRunnerState: String, Codable, Sendable { case preparing, working, resting, roundRest, paused, completed, cancelled }
public enum ActivityStatus: String, Codable, CaseIterable, Sendable { case proposed, completed, skipped, snoozed, replaced }
public enum ActivitySource: String, Codable, Sendable { case hourly, quickWorkout, customWorkout, freeMovement, manual }
public enum HumorMode: String, Codable, CaseIterable, Sendable { case normal, discreet, disabled }
public enum AnimationMode: String, Codable, CaseIterable, Sendable { case full, reduced, disabled }
public enum SoundMode: String, Codable, CaseIterable, Sendable { case off, discreet, normal }
public enum ReminderScreenTarget: String, Codable, CaseIterable, Sendable { case main, active, macBook }
public enum ReminderHostPreference: String, Codable, CaseIterable, Sendable { case phoneAndWatch, mac, all }

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
    public var easierVariantID: String?
    public var harderVariantID: String?
    public init(id: String, name: String, category: ExerciseCategory, metric: ExerciseMetric, defaultAmount: Int, difficulty: Int = 1, equipment: Set<String> = [], tags: Set<String> = [], emoji: String, easierVariantID: String? = nil, harderVariantID: String? = nil) {
        self.id = id; self.name = name; self.category = category; self.metric = metric; self.defaultAmount = defaultAmount; self.difficulty = difficulty; self.equipment = equipment; self.tags = tags; self.emoji = emoji; self.easierVariantID = easierVariantID; self.harderVariantID = harderVariantID
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

public struct MovementPreferences: Codable, Equatable, Sendable {
    public var disabledExerciseIDs: Set<String> = []
    public var availableEquipment: Set<String> = []
    public var excludedTags: Set<String> = []
    public var preferredDifficulty: ClosedRange<Int> = 1...3
    public init() {}
}

public struct ReminderPreferences: Codable, Equatable, Sendable {
    public var enabled = true
    public var intervalMinutes = 60
    public var activeStartHour = 9
    public var activeEndHour = 19
    public var enabledWeekdays: Set<Int> = [2, 3, 4, 5, 6]
    public var snoozeMinutes = 15
    public var notificationsDuringFullScreen = false
    public var notificationsDuringMeetings = false
    public var greaseTheGrooveEnabled = false
    public var greaseTheGrooveExerciseID: String?
    public var greaseTheGrooveRepMax = 10
    public var greaseTheGroovePercentage = 50
    public var greaseTheGrooveCalibrationIntervalDays = 30
    public var greaseTheGrooveLastCalibratedAt: Date?
    public init() {}
    private enum CodingKeys: String, CodingKey { case enabled, intervalMinutes, activeStartHour, activeEndHour, enabledWeekdays, snoozeMinutes, notificationsDuringFullScreen, notificationsDuringMeetings, greaseTheGrooveEnabled, greaseTheGrooveExerciseID, greaseTheGrooveRepMax, greaseTheGroovePercentage, greaseTheGrooveCalibrationIntervalDays, greaseTheGrooveLastCalibratedAt }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        intervalMinutes = try values.decodeIfPresent(Int.self, forKey: .intervalMinutes) ?? 60
        activeStartHour = try values.decodeIfPresent(Int.self, forKey: .activeStartHour) ?? 9
        activeEndHour = try values.decodeIfPresent(Int.self, forKey: .activeEndHour) ?? 19
        enabledWeekdays = try values.decodeIfPresent(Set<Int>.self, forKey: .enabledWeekdays) ?? [2, 3, 4, 5, 6]
        snoozeMinutes = try values.decodeIfPresent(Int.self, forKey: .snoozeMinutes) ?? 15
        notificationsDuringFullScreen = try values.decodeIfPresent(Bool.self, forKey: .notificationsDuringFullScreen) ?? false
        notificationsDuringMeetings = try values.decodeIfPresent(Bool.self, forKey: .notificationsDuringMeetings) ?? false
        greaseTheGrooveEnabled = try values.decodeIfPresent(Bool.self, forKey: .greaseTheGrooveEnabled) ?? false
        greaseTheGrooveExerciseID = try values.decodeIfPresent(String.self, forKey: .greaseTheGrooveExerciseID)
        greaseTheGrooveRepMax = try values.decodeIfPresent(Int.self, forKey: .greaseTheGrooveRepMax) ?? 10
        greaseTheGroovePercentage = try values.decodeIfPresent(Int.self, forKey: .greaseTheGroovePercentage) ?? 50
        greaseTheGrooveCalibrationIntervalDays = try values.decodeIfPresent(Int.self, forKey: .greaseTheGrooveCalibrationIntervalDays) ?? 30
        greaseTheGrooveLastCalibratedAt = try values.decodeIfPresent(Date.self, forKey: .greaseTheGrooveLastCalibratedAt)
    }
}

public struct AppearancePreferences: Codable, Equatable, Sendable {
    public var humor: HumorMode = .normal
    public var emojisEnabled = true
    public var animations: AnimationMode = .full
    public var sounds: SoundMode = .off
    public var screenTarget: ReminderScreenTarget = .main
    public init() {}
}

public struct ReminderState: Codable, Equatable, Sendable {
    public var nextReminderAt: Date?
    public var lastReminderAt: Date?
    public var lastUserInteractionAt: Date?
    public var pausedUntil: Date?
    public var snoozedReminderAt: Date?
    public var snoozedExerciseID: String?
    public init(nextReminderAt: Date? = nil, lastReminderAt: Date? = nil, lastUserInteractionAt: Date? = nil, pausedUntil: Date? = nil, snoozedReminderAt: Date? = nil, snoozedExerciseID: String? = nil) {
        self.nextReminderAt = nextReminderAt; self.lastReminderAt = lastReminderAt
        self.lastUserInteractionAt = lastUserInteractionAt; self.pausedUntil = pausedUntil
        self.snoozedReminderAt = snoozedReminderAt; self.snoozedExerciseID = snoozedExerciseID
    }
    private enum CodingKeys: String, CodingKey { case nextReminderAt, lastReminderAt, lastUserInteractionAt, pausedUntil, snoozedReminderAt, snoozedExerciseID }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        nextReminderAt = try values.decodeIfPresent(Date.self, forKey: .nextReminderAt)
        lastReminderAt = try values.decodeIfPresent(Date.self, forKey: .lastReminderAt)
        lastUserInteractionAt = try values.decodeIfPresent(Date.self, forKey: .lastUserInteractionAt)
        pausedUntil = try values.decodeIfPresent(Date.self, forKey: .pausedUntil)
        snoozedReminderAt = try values.decodeIfPresent(Date.self, forKey: .snoozedReminderAt)
        snoozedExerciseID = try values.decodeIfPresent(String.self, forKey: .snoozedExerciseID)
    }
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
    public var description: String
    public var emoji: String
    public var rounds: Int
    public var preparationSeconds: Int
    public var roundRestSeconds: Int
    public var finalRecoverySeconds: Int
    public var steps: [WorkoutStep]
    public var mode: WorkoutMode
    public init(id: UUID = UUID(), name: String, description: String = "", emoji: String = "💪", rounds: Int, preparationSeconds: Int = 0, roundRestSeconds: Int = 0, finalRecoverySeconds: Int = 0, steps: [WorkoutStep], mode: WorkoutMode = .interval) {
        self.id = id; self.name = name; self.description = description; self.emoji = emoji; self.rounds = rounds
        self.preparationSeconds = preparationSeconds; self.roundRestSeconds = roundRestSeconds; self.finalRecoverySeconds = finalRecoverySeconds
        self.steps = steps; self.mode = mode
    }
    private enum CodingKeys: String, CodingKey { case id, name, description, emoji, rounds, preparationSeconds, roundRestSeconds, finalRecoverySeconds, steps, mode }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        description = try values.decodeIfPresent(String.self, forKey: .description) ?? ""
        emoji = try values.decodeIfPresent(String.self, forKey: .emoji) ?? "💪"
        rounds = try values.decode(Int.self, forKey: .rounds)
        preparationSeconds = try values.decodeIfPresent(Int.self, forKey: .preparationSeconds) ?? 0
        roundRestSeconds = try values.decodeIfPresent(Int.self, forKey: .roundRestSeconds) ?? 0
        finalRecoverySeconds = try values.decodeIfPresent(Int.self, forKey: .finalRecoverySeconds) ?? 0
        steps = try values.decode([WorkoutStep].self, forKey: .steps)
        mode = try values.decode(WorkoutMode.self, forKey: .mode)
    }
    public var estimatedDuration: Int {
        max(0, preparationSeconds) + rounds * steps.reduce(0) { $0 + $1.workSeconds + $1.restSeconds } + max(0, roundRestSeconds) * max(0, rounds - 1) + max(0, finalRecoverySeconds)
    }
    public var validationError: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Le nom est requis." }
        if rounds < 1 { return "La séance doit contenir au moins un tour." }
        if steps.isEmpty { return "Ajoute au moins un mouvement." }
        if steps.contains(where: { $0.workSeconds < 0 || $0.restSeconds < 0 }) || preparationSeconds < 0 || roundRestSeconds < 0 || finalRecoverySeconds < 0 { return "Les durées ne peuvent pas être négatives." }
        if mode == .interval && steps.allSatisfy({ $0.workSeconds == 0 }) { return "Le temps de travail doit être supérieur à zéro." }
        if mode == .repetitions && steps.contains(where: { $0.workSeconds <= 0 }) { return "Chaque étape doit contenir au moins une répétition." }
        if estimatedDuration > 2 * 60 * 60 { return "La séance est trop longue." }
        return nil
    }
}
