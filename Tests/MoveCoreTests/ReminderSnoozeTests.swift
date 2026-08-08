import Foundation
import Testing
@testable import MoveCore

@Test func snoozePreservesFollowingNormalSlot() {
    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3, hour: 10))!
    let snooze = now.addingTimeInterval(15 * 60)
    var state = ReminderState(snoozedReminderAt: snooze, snoozedExerciseID: "squats")
    let request = ReminderPlanRequest(now: now, horizon: now.addingTimeInterval(3 * 3600), state: state, exercises: [ExerciseLibrary.builtIn.first { $0.id == "squats" }!], calendar: calendar)
    let plan = ReminderPlanner().plan(request)
    #expect(plan.map(\.fireDate).contains(snooze))
    #expect(plan.map(\.fireDate).contains(calendar.date(byAdding: .hour, value: 1, to: now)!))
    #expect(plan.first?.kind == .snoozed)
    state.snoozedReminderAt = now.addingTimeInterval(60 * 60)
    let collision = ReminderPlanner().plan(request.with(state: state))
    #expect(collision.filter { $0.fireDate == state.snoozedReminderAt }.count == 1)
    #expect(collision.first?.kind == .snoozed)
}

private extension ReminderPlanRequest {
    func with(state: ReminderState) -> ReminderPlanRequest {
        .init(now: now, horizon: horizon, maximumCount: maximumCount, preferences: preferences, state: state, exercises: exercises, recentExerciseIDs: recentExerciseIDs, calendar: calendar)
    }
}

@Test func snoozeBeyondOneHourAfterEndIsRejected() {
    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3, hour: 18))!
    let tooLate = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3, hour: 20, minute: 1))!
    let state = ReminderState(snoozedReminderAt: tooLate, snoozedExerciseID: "squats")
    let request = ReminderPlanRequest(now: now, horizon: now.addingTimeInterval(4 * 3600), state: state, exercises: [ExerciseLibrary.builtIn.first { $0.id == "squats" }!], calendar: calendar)
    #expect(!ReminderPlanner().plan(request).contains { $0.kind == .snoozed })
}
