import Foundation
import Testing
@testable import MoveCore

@Test func selectorRespectsEquipmentAndTags() {
    var preferences = MovementPreferences()
    preferences.excludedTags = ["floor"]
    let candidates = ExerciseSelector().candidates(from: ExerciseLibrary.builtIn, preferences: preferences)
    #expect(!candidates.contains { $0.tags.contains("floor") })
    #expect(!candidates.contains { !$0.equipment.isEmpty })
}

@Test func exerciseLibraryHasV1Coverage() {
    #expect(ExerciseLibrary.all.count >= 50)
    #expect(Set(ExerciseLibrary.all.map(\.category)).count >= 5)
}

@Test func selectorAdaptsToRepeatedRefusals() {
    let easy = Exercise(id: "easy", name: "Facile", category: .strength, metric: .repetitions, defaultAmount: 8, emoji: "🙂")
    let hard = Exercise(id: "hard", name: "Difficile", category: .strength, metric: .repetitions, defaultAmount: 10, difficulty: 2, emoji: "💪")
    var source = easy; source.easierVariantID = "hard"
    let adapted = ExerciseSelector().adapted(source, from: [source, hard], refusals: 2, easyCompletions: 0)
    #expect(adapted.id == "hard")
    #expect(adapted.defaultAmount == 8)
}

@Test func statisticsCanBeLimitedToPeriod() {
    let now = Date()
    let recent = ActivityRecord(exerciseID: "squats", performedAt: now, amount: 10, metric: .repetitions, status: .completed, source: .manual)
    let old = ActivityRecord(exerciseID: "pushups", performedAt: now.addingTimeInterval(-86400 * 10), amount: 20, metric: .repetitions, status: .completed, source: .manual)
    let stats = StatisticsService.calculate([recent, old], since: now.addingTimeInterval(-86400))
    #expect(stats.completedCount == 1)
    #expect(stats.totalRepetitions == 10)
}

@Test func workoutValidationRejectsEmptyWorkout() {
    let workout = WorkoutTemplate(name: "", rounds: 0, steps: [])
    #expect(workout.validationError != nil)
}

@Test func workoutValidationAcceptsNormalWorkout() {
    let workout = WorkoutTemplate(name: "Pause bureau", rounds: 2, steps: [.init(exerciseID: "squats")])
    #expect(workout.validationError == nil)
}

@Test func exportCSVContainsHeaderAndRecord() {
    let record = ActivityRecord(exerciseID: "squats", amount: 10, metric: .repetitions, status: .completed, source: .hourly)
    let csv = DataTransferService.exportCSV([record])
    #expect(csv.hasPrefix("id,exercise_id,performed_at,amount"))
    #expect(csv.contains("squats"))
}

@Test func exportJSONIsDecodable() throws {
    let record = ActivityRecord(exerciseID: "plank", amount: 30, metric: .seconds, status: .completed, source: .freeMovement)
    let data = try DataTransferService.exportJSON([record])
    let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
    let decoded = try decoder.decode([ActivityRecord].self, from: data)
    #expect(decoded.count == 1)
    #expect(decoded[0].id == record.id)
    #expect(decoded[0].exerciseID == record.exerciseID)
    #expect(abs(decoded[0].performedAt.timeIntervalSince(record.performedAt)) < 0.001)
}

@Test func importJSONSkipsExistingRecords() throws {
    let record = ActivityRecord(exerciseID: "squats", amount: 10, metric: .repetitions, status: .completed, source: .hourly)
    let data = try DataTransferService.exportJSON([record])
    #expect(try DataTransferService.importJSON(data, existing: [record]).isEmpty)
}

@Test func selectorUsesAvailableEquipment() {
    var preferences = MovementPreferences()
    preferences.availableEquipment = ["pullup-bar"]
    let candidates = ExerciseSelector().candidates(from: ExerciseLibrary.builtIn, preferences: preferences)
    #expect(candidates.contains { $0.id == "pullups" })
}

@Test func workoutDurationIsComputed() {
    let workout = WorkoutTemplate(name: "Test", rounds: 2, steps: [.init(exerciseID: "squats", workSeconds: 40, restSeconds: 20)])
    #expect(workout.estimatedDuration == 120)
}

@Test func statisticsAggregateMetrics() {
    let records = [
        ActivityRecord(exerciseID: "pushups", amount: 10, metric: .repetitions, status: .completed, source: .hourly),
        ActivityRecord(exerciseID: "plank", amount: 60, metric: .seconds, status: .completed, source: .hourly),
        ActivityRecord(exerciseID: "squats", amount: 15, metric: .repetitions, status: .skipped, source: .hourly)
    ]
    let stats = StatisticsService.calculate(records)
    #expect(stats.completedCount == 2)
    #expect(stats.totalRepetitions == 10)
    #expect(stats.activeSeconds == 60)
    #expect(stats.bestDayCompletedCount == 2)
    #expect(stats.longestStreak == 1)
}

@Test func statisticsExposeExerciseRecords() {
    let first = Date(timeIntervalSince1970: 1_000_000)
    let records = [
        ActivityRecord(exerciseID: "squats", performedAt: first, amount: 10, metric: .repetitions, status: .completed, source: .manual),
        ActivityRecord(exerciseID: "squats", performedAt: first.addingTimeInterval(3600), amount: 12, metric: .repetitions, status: .completed, source: .manual),
        ActivityRecord(exerciseID: "squats", performedAt: first, amount: 5, metric: .repetitions, status: .skipped, source: .manual)
    ]
    let stats = StatisticsService.forExercise(records, exerciseID: "squats")
    #expect(stats.completedCount == 2)
    #expect(stats.totalAmount == 22)
    #expect(stats.bestDayAmount == 22)
}

@Test func schedulerRejectsUnsafeIntervals() {
    var preferences = ReminderPreferences()
    preferences.intervalMinutes = 5
    #expect(ReminderScheduler().nextDate(after: .now, preferences: preferences) == nil)
}

@Test func pausedSchedulerReturnsPauseBoundary() {
    let now = Date(timeIntervalSince1970: 1000)
    let pause = now.addingTimeInterval(3600)
    let state = ReminderState(pausedUntil: pause)
    #expect(ReminderScheduler().nextDate(now: now, preferences: .init(), state: state) == pause)
}
