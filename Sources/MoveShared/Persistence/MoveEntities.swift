import Foundation
import SwiftData
import MoveCore

@Model public final class ActivityEntity {
    public var id: UUID
    public var exerciseID: String
    public var performedAt: Date
    public var amount: Int
    public var metricRaw: String
    public var statusRaw: String
    public var sourceRaw: String
    public var workoutID: UUID?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(record: ActivityRecord) {
        id = record.id
        exerciseID = record.exerciseID
        performedAt = record.performedAt
        amount = record.amount
        metricRaw = record.metric.rawValue
        statusRaw = record.status.rawValue
        sourceRaw = record.source.rawValue
        workoutID = record.workoutID
        createdAt = record.performedAt
        updatedAt = .now
    }

    public var record: ActivityRecord {
        .init(
            id: id,
            exerciseID: exerciseID,
            performedAt: performedAt,
            amount: amount,
            metric: ExerciseMetric(rawValue: metricRaw) ?? .free,
            status: ActivityStatus(rawValue: statusRaw) ?? .completed,
            source: ActivitySource(rawValue: sourceRaw) ?? .hourly,
            workoutID: workoutID
        )
    }

    public func update(amount: Int, status: ActivityStatus? = nil) {
        self.amount = max(0, amount)
        if let status { statusRaw = status.rawValue }
        updatedAt = .now
    }
}

@Model public final class AppSettingsEntity {
    public var id: String
    public var reminderData: Data
    public var movementData: Data
    public var appearanceData: Data
    public var reminderHostRaw: String
    public var updatedAt: Date

    public init(
        reminder: ReminderPreferences = .init(),
        movement: MovementPreferences = .init(),
        appearance: AppearancePreferences = .init(),
        reminderHost: ReminderHostPreference = .phoneAndWatch
    ) {
        id = "settings"
        reminderData = (try? JSONEncoder().encode(reminder)) ?? Data()
        movementData = (try? JSONEncoder().encode(movement)) ?? Data()
        appearanceData = (try? JSONEncoder().encode(appearance)) ?? Data()
        reminderHostRaw = reminderHost.rawValue
        updatedAt = .now
    }

    public func values() -> (ReminderPreferences, MovementPreferences, AppearancePreferences) {
        let reminder = (try? JSONDecoder().decode(ReminderPreferences.self, from: reminderData)) ?? .init()
        let movement = (try? JSONDecoder().decode(MovementPreferences.self, from: movementData)) ?? .init()
        let appearance = (try? JSONDecoder().decode(AppearancePreferences.self, from: appearanceData)) ?? .init()
        return (reminder, movement, appearance)
    }

    public var reminderHost: ReminderHostPreference {
        get { ReminderHostPreference(rawValue: reminderHostRaw) ?? .phoneAndWatch }
        set {
            reminderHostRaw = newValue.rawValue
            updatedAt = .now
        }
    }
}

@Model public final class CustomExerciseEntity {
    public var id: String
    public var name: String
    public var emoji: String
    public var categoryRaw: String
    public var metricRaw: String
    public var defaultAmount: Int
    public var archived: Bool
    public var instructions: String
    public var equipmentRaw: String = ""
    public var tagsRaw: String = ""
    public var muscleZonesRaw: String = ""
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = "custom-\(UUID().uuidString)",
        name: String,
        emoji: String = "💪",
        category: ExerciseCategory = .strength,
        metric: ExerciseMetric = .repetitions,
        defaultAmount: Int = 10,
        instructions: String = "",
        equipment: Set<String> = [],
        tags: Set<String> = [],
        muscleZones: Set<String> = []
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        categoryRaw = category.rawValue
        metricRaw = metric.rawValue
        self.defaultAmount = defaultAmount
        archived = false
        self.instructions = instructions
        equipmentRaw = equipment.sorted().joined(separator: ",")
        tagsRaw = tags.sorted().joined(separator: ",")
        muscleZonesRaw = muscleZones.sorted().joined(separator: ",")
        createdAt = .now
        updatedAt = .now
    }

    public var exercise: Exercise? {
        guard let category = ExerciseCategory(rawValue: categoryRaw),
              let metric = ExerciseMetric(rawValue: metricRaw) else { return nil }
        let difficulty = tags.compactMap {
            $0.hasPrefix("difficulty-") ? Int(String($0.dropFirst("difficulty-".count))) : nil
        }.first ?? 1
        let easier = tags.first { $0.hasPrefix("easier-") }.map { String($0.dropFirst("easier-".count)) }
        let harder = tags.first { $0.hasPrefix("harder-") }.map { String($0.dropFirst("harder-".count)) }
        return Exercise(
            id: id,
            name: name,
            category: category,
            metric: metric,
            defaultAmount: max(0, defaultAmount),
            difficulty: min(3, max(1, difficulty)),
            equipment: equipment,
            tags: tags.union(muscleZones.map { "zone-\($0)" }).union(["personnalisé"]),
            emoji: emoji,
            easierVariantID: easier,
            harderVariantID: harder
        )
    }

    public var equipment: Set<String> { Set(equipmentRaw.split(separator: ",").map(String.init)) }
    public var tags: Set<String> { Set(tagsRaw.split(separator: ",").map(String.init)) }
    public var muscleZones: Set<String> { Set(muscleZonesRaw.split(separator: ",").map(String.init)) }
}

@Model public final class ExerciseEntity {
    public var id: String
    public var name: String
    public var categoryRaw: String
    public var metricRaw: String
    public var defaultAmount: Int
    public var archived: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String, name: String, categoryRaw: String, metricRaw: String, defaultAmount: Int, archived: Bool = false) {
        self.id = id
        self.name = name
        self.categoryRaw = categoryRaw
        self.metricRaw = metricRaw
        self.defaultAmount = defaultAmount
        self.archived = archived
        createdAt = .now
        updatedAt = .now
    }
}

@Model public final class ReminderStateEntity {
    public var id: String
    public var nextReminderAt: Date?
    public var lastReminderAt: Date?
    public var lastUserInteractionAt: Date?
    public var pausedUntil: Date?
    public var snoozedReminderAt: Date?
    public var snoozedExerciseID: String?
    public var updatedAt: Date

    public init(state: ReminderState = .init()) {
        id = "reminder-state"
        nextReminderAt = state.nextReminderAt
        lastReminderAt = state.lastReminderAt
        lastUserInteractionAt = state.lastUserInteractionAt
        pausedUntil = state.pausedUntil
        snoozedReminderAt = state.snoozedReminderAt
        snoozedExerciseID = state.snoozedExerciseID
        updatedAt = .now
    }

    public var state: ReminderState {
        .init(
            nextReminderAt: nextReminderAt,
            lastReminderAt: lastReminderAt,
            lastUserInteractionAt: lastUserInteractionAt,
            pausedUntil: pausedUntil,
            snoozedReminderAt: snoozedReminderAt,
            snoozedExerciseID: snoozedExerciseID
        )
    }
}

@Model public final class WorkoutSessionEntity {
    public var id: UUID
    public var workoutID: UUID
    public var workoutName: String
    public var stepIndex: Int
    public var round: Int
    public var secondsRemaining: Int
    public var plannedDurationSeconds: Int = 0
    public var stateRaw: String
    public var startedAt: Date
    public var updatedAt: Date

    public init(
        workout: WorkoutTemplate,
        stepIndex: Int = 0,
        round: Int = 1,
        secondsRemaining: Int = 0,
        state: WorkoutRunnerState = .preparing
    ) {
        id = UUID()
        workoutID = workout.id
        workoutName = workout.name
        self.stepIndex = stepIndex
        self.round = round
        self.secondsRemaining = secondsRemaining
        stateRaw = state.rawValue
        plannedDurationSeconds = workout.estimatedDuration
        startedAt = .now
        updatedAt = .now
    }
}

@Model public final class WorkoutStepResultEntity {
    public var id: UUID
    public var sessionID: UUID
    public var stepID: UUID
    public var exerciseID: String
    public var round: Int
    public var statusRaw: String
    public var amount: Int
    public var durationSeconds: Int
    public var completedAt: Date

    public init(sessionID: UUID, stepID: UUID, exerciseID: String, round: Int, status: ActivityStatus, amount: Int, durationSeconds: Int) {
        id = UUID()
        self.sessionID = sessionID
        self.stepID = stepID
        self.exerciseID = exerciseID
        self.round = round
        statusRaw = status.rawValue
        self.amount = amount
        self.durationSeconds = durationSeconds
        completedAt = .now
    }
}

@Model public final class WorkoutTemplateEntity {
    public var id: UUID
    public var name: String
    public var templateData: Data
    public var archived: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(template: WorkoutTemplate) {
        id = template.id
        name = template.name
        templateData = (try? JSONEncoder().encode(template)) ?? Data()
        archived = false
        createdAt = .now
        updatedAt = .now
    }

    public var template: WorkoutTemplate? { try? JSONDecoder().decode(WorkoutTemplate.self, from: templateData) }
}

public enum MoveSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)
    public static let models: [any PersistentModel.Type] = [
        ActivityEntity.self, ExerciseEntity.self, WorkoutTemplateEntity.self,
        WorkoutSessionEntity.self, WorkoutStepResultEntity.self, AppSettingsEntity.self,
        CustomExerciseEntity.self, ReminderStateEntity.self
    ]
    public static var schema: Schema { Schema(models) }
}

public enum MoveSchemaV2: VersionedSchema {
    public static let versionIdentifier = Schema.Version(2, 0, 0)
    public static let models: [any PersistentModel.Type] = MoveSchemaV1.models
    public static var schema: Schema { Schema(models) }
}

public enum MoveMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [MoveSchemaV1.self, MoveSchemaV2.self] }
    public static var stages: [MigrationStage] {
        [.lightweight(fromVersion: MoveSchemaV1.self, toVersion: MoveSchemaV2.self)]
    }
}
