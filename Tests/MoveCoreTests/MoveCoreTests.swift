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

@Test func quickWorkoutPresetsCoverV1List() {
    #expect(ExerciseLibrary.quickWorkouts.count >= 13)
    #expect(ExerciseLibrary.quickWorkouts.contains { $0.name.contains("Mouvement libre") })
    #expect(ExerciseLibrary.quickWorkouts.allSatisfy { $0.validationError == nil })
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

@Test func importPreviewSummarizesExistingAndRepeatedRecords() throws {
    let existing = ActivityRecord(exerciseID: "squats", amount: 10, metric: .repetitions, status: .completed, source: .hourly)
    let fresh = ActivityRecord(exerciseID: "plank", amount: 30, metric: .seconds, status: .completed, source: .manual)
    let data = try DataTransferService.exportJSON([existing, fresh, fresh])
    let preview = try DataTransferService.previewImport(data, existing: [existing])
    #expect(preview.summary.total == 3)
    #expect(preview.summary.newRecords == 1)
    #expect(preview.summary.duplicateRecords == 2)
    #expect(preview.records.first?.id == fresh.id)
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

@Test func wakeSchedulerSchedulesOnlyOneFutureReminder() {
    let calendar = Calendar(identifier: .gregorian)
    let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3, hour: 11, minute: 0))!
    var preferences = ReminderPreferences()
    preferences.intervalMinutes = 60
    preferences.activeStartHour = 9
    preferences.activeEndHour = 19
    preferences.enabledWeekdays = [2, 3, 4, 5, 6]
    let next = ReminderScheduler().nextDateAfterWake(now: now, preferences: preferences, state: .init(), wakeDelay: 60, calendar: calendar)
    #expect(next != nil)
    #expect(next! > now.addingTimeInterval(60))
    #expect(next! < now.addingTimeInterval(2 * 60 * 60))
}

@Test func schedulerSkipsDisabledDaysAndInactiveHours() {
    let calendar = Calendar(identifier: .gregorian)
    let sunday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 2, hour: 18, minute: 30))!
    var preferences = ReminderPreferences()
    preferences.intervalMinutes = 30
    preferences.activeStartHour = 9
    preferences.activeEndHour = 17
    preferences.enabledWeekdays = [2] // Monday only

    let next = ReminderScheduler().nextDate(after: sunday, preferences: preferences, calendar: calendar)

    #expect(next == calendar.date(from: DateComponents(year: 2026, month: 8, day: 3, hour: 9, minute: 0)))
}

@Test func wakeSchedulerClampsDelayToSafeWindow() {
    let calendar = Calendar(identifier: .gregorian)
    let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3, hour: 11))!
    var preferences = ReminderPreferences()
    preferences.intervalMinutes = 15
    preferences.activeStartHour = 9
    preferences.activeEndHour = 19
    preferences.enabledWeekdays = [2, 3, 4, 5, 6]

    let next = ReminderScheduler().nextDateAfterWake(now: now, preferences: preferences, state: .init(), wakeDelay: 300, calendar: calendar)

    #expect(next != nil)
    #expect(next! >= now.addingTimeInterval(90 + 15 * 60))
}

@Test func reminderDeliveryPolicySuppressesDisabledContexts() {
    let preferences = ReminderPreferences()
    #expect(!ReminderDeliveryPolicy.shouldDeliver(isFullScreen: true, isMeeting: false, preferences: preferences))
    #expect(!ReminderDeliveryPolicy.shouldDeliver(isFullScreen: false, isMeeting: true, preferences: preferences))
    #expect(ReminderDeliveryPolicy.shouldDeliver(isFullScreen: false, isMeeting: false, preferences: preferences))
}

@Test func reminderDeliveryPolicyAllowsExplicitOptIn() {
    var preferences = ReminderPreferences()
    preferences.notificationsDuringFullScreen = true
    preferences.notificationsDuringMeetings = true
    #expect(ReminderDeliveryPolicy.shouldDeliver(isFullScreen: true, isMeeting: true, preferences: preferences))
}
