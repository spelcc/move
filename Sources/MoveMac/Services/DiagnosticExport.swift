import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import MoveCore
import MoveShared

struct MoveDiagnosticReport: Codable {
    let generatedAt: Date
    let appVersion: String
    let osVersion: String
    let schemaVersion: String
    let cloudKitMode: String
    let reminderHost: ReminderHostPreference
    let reminderQueueCapacity: Int
    let activityCount: Int
    let customExerciseCount: Int
    let workoutTemplateCount: Int
    let workoutSessionCount: Int
    let workoutStepResultCount: Int
    let remindersEnabled: Bool
    let nextReminderAt: Date?
    let pausedUntil: Date?
    let soundMode: SoundMode
    let screenTarget: ReminderScreenTarget
    let persistenceIssue: String?

    @MainActor static func make(context: ModelContext, store: MoveStore, persistenceIssue: String?) -> Self {
        let activities = (try? context.fetch(FetchDescriptor<ActivityEntity>()).count) ?? 0
        let customExercises = (try? context.fetch(FetchDescriptor<CustomExerciseEntity>()).count) ?? 0
        let templates = (try? context.fetch(FetchDescriptor<WorkoutTemplateEntity>()).count) ?? 0
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSessionEntity>()).count) ?? 0
        let results = (try? context.fetch(FetchDescriptor<WorkoutStepResultEntity>()).count) ?? 0
        return .init(
            generatedAt: .now,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            schemaVersion: "MoveSchemaV2",
            cloudKitMode: "localOnly",
            reminderHost: store.reminderHost,
            reminderQueueCapacity: 64,
            activityCount: activities,
            customExerciseCount: customExercises,
            workoutTemplateCount: templates,
            workoutSessionCount: sessions,
            workoutStepResultCount: results,
            remindersEnabled: store.reminder.intervalMinutes >= 15,
            nextReminderAt: store.reminderState.nextReminderAt,
            pausedUntil: store.reminderState.pausedUntil,
            soundMode: store.appearance.sounds,
            screenTarget: store.appearance.screenTarget,
            persistenceIssue: persistenceIssue
        )
    }
}

struct DiagnosticDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data = Data()

    init() {}

    init(report: MoveDiagnosticReport) {
        data = (try? JSONEncoder.moveDiagnostic.encode(report)) ?? Data()
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private extension JSONEncoder {
    static var moveDiagnostic: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
