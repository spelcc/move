import Foundation
import Testing
@testable import MoveCore

private func date(_ hour: Int, _ minute: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar.date(from: DateComponents(calendar: calendar, year: 2026, month: 8, day: 3, hour: hour, minute: minute))!
}

@Test func plannerResumesAfterPauseWithoutSchedulingDuringIt() {
    let calendar = Calendar(identifier: .gregorian)
    let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 7, hour: 9))!
    let pause = calendar.date(byAdding: .hour, value: 2, to: now)!
    let horizon = calendar.date(byAdding: .day, value: 1, to: now)!
    var preferences = ReminderPreferences()
    preferences.enabledWeekdays = Set(1...7)
    var state = ReminderState()
    state.pausedUntil = pause
    let plan = ReminderPlanner().plan(.init(
        now: now,
        horizon: horizon,
        preferences: preferences,
        state: state,
        exercises: [ExerciseLibrary.all[0]],
        calendar: calendar
    ))
    #expect(plan.first?.fireDate ?? .distantPast > pause)
}

@Test func plannerBuildsMoreThanOneReminder() {
    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let request = ReminderPlanRequest(now: date(8), horizon: date(8).addingTimeInterval(86400), maximumCount: 20, exercises: [ExerciseLibrary.builtIn[0]], calendar: calendar)
    let plan = ReminderPlanner().plan(request)
    #expect(plan.count == 10)
    #expect(plan.first?.fireDate == date(9))
    #expect(plan.last?.fireDate == date(18))
}

@Test func plannerHonorsMaximumAndDisabledWeekdays() {
    var preferences = ReminderPreferences(); preferences.enabledWeekdays = [2]; preferences.intervalMinutes = 30
    let calendar = Calendar(identifier: .gregorian)
    let request = ReminderPlanRequest(now: date(8), horizon: date(8).addingTimeInterval(3 * 86400), maximumCount: 3, preferences: preferences, exercises: [ExerciseLibrary.builtIn[0]], calendar: calendar)
    let plan = ReminderPlanner().plan(request)
    #expect(plan.count == 3)
    #expect(plan.allSatisfy { calendar.component(.weekday, from: $0.fireDate) == 2 })
}

@Test func plannerIsDeterministic() {
    let now = date(8); let calendar = Calendar(identifier: .gregorian)
    let request = ReminderPlanRequest(now: now, horizon: now.addingTimeInterval(86400), exercises: ExerciseLibrary.builtIn, calendar: calendar)
    #expect(ReminderPlanner().plan(request) == ReminderPlanner().plan(request))
}

@Test func greaseTheGrooveUsesOneExerciseAndTargetPercentage() {
    var preferences = ReminderPreferences()
    preferences.enabledWeekdays = Set(1...7)
    preferences.greaseTheGrooveEnabled = true
    preferences.greaseTheGrooveExerciseID = ExerciseLibrary.builtIn[0].id
    preferences.greaseTheGrooveRepMax = 20
    preferences.greaseTheGroovePercentage = 50
    let plan = ReminderPlanner().plan(.init(
        now: date(8), horizon: date(8).addingTimeInterval(86400),
        preferences: preferences, exercises: ExerciseLibrary.builtIn,
        calendar: Calendar(identifier: .gregorian)
    ))
    #expect(!plan.isEmpty)
    #expect(Set(plan.map(\.exerciseID)) == [ExerciseLibrary.builtIn[0].id])
    #expect(plan.allSatisfy { $0.targetAmount == 10 })
}
