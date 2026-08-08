import SwiftData

enum MoveSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static let models: [any PersistentModel.Type] = [
        ActivityEntity.self, ExerciseEntity.self, WorkoutTemplateEntity.self,
        WorkoutSessionEntity.self, WorkoutStepResultEntity.self, AppSettingsEntity.self,
        CustomExerciseEntity.self, ReminderStateEntity.self
    ]
    static var schema: Schema { Schema(models) }
}

enum MoveSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static let models: [any PersistentModel.Type] = MoveSchemaV1.models
    static var schema: Schema { Schema(models) }
}

enum MoveMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [MoveSchemaV1.self, MoveSchemaV2.self] }
    static var stages: [MigrationStage] { [.lightweight(fromVersion: MoveSchemaV1.self, toVersion: MoveSchemaV2.self)] }
}
