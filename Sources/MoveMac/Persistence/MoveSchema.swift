import SwiftData

enum MoveSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static let models: [any PersistentModel.Type] = [
        ActivityEntity.self, ExerciseEntity.self, WorkoutTemplateEntity.self,
        WorkoutSessionEntity.self, WorkoutStepResultEntity.self, AppSettingsEntity.self,
        CustomExerciseEntity.self, ReminderStateEntity.self
    ]
}

enum MoveMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [MoveSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
