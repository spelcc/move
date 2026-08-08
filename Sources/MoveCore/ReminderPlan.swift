import Foundation

public enum ReminderKind: String, Codable, Sendable { case scheduled, snoozed }

public struct PlannedReminder: Identifiable, Equatable, Sendable {
    public let id: String
    public let fireDate: Date
    public let exerciseID: String
    public let kind: ReminderKind
    public init(id: String, fireDate: Date, exerciseID: String, kind: ReminderKind) {
        self.id = id; self.fireDate = fireDate; self.exerciseID = exerciseID; self.kind = kind
    }
}

public struct ReminderPlanRequest: Sendable {
    public let now: Date
    public let horizon: Date
    public let maximumCount: Int
    public let preferences: ReminderPreferences
    public let state: ReminderState
    public let exercises: [Exercise]
    public let recentExerciseIDs: [String]
    public let calendar: Calendar
    public init(now: Date, horizon: Date, maximumCount: Int = 100, preferences: ReminderPreferences = .init(), state: ReminderState = .init(), exercises: [Exercise], recentExerciseIDs: [String] = [], calendar: Calendar = .current) {
        self.now = now; self.horizon = horizon; self.maximumCount = maximumCount; self.preferences = preferences; self.state = state; self.exercises = exercises; self.recentExerciseIDs = recentExerciseIDs; self.calendar = calendar
    }
}

public struct ReminderPlanner: Sendable {
    public init() {}
    public func plan(_ request: ReminderPlanRequest) -> [PlannedReminder] {
        guard request.preferences.enabled, request.maximumCount > 0, !request.exercises.isEmpty,
              request.preferences.intervalMinutes >= 15,
              request.preferences.activeStartHour < request.preferences.activeEndHour,
              request.horizon > request.now else { return [] }
        let planningStart = max(request.now, request.state.pausedUntil ?? request.now)
        let selector = ExerciseSelector()
        let available = request.exercises
        guard !available.isEmpty else { return [] }
        var result: [PlannedReminder] = []
        var day = request.calendar.startOfDay(for: planningStart)
        while day < request.horizon && result.count < request.maximumCount {
            let weekday = request.calendar.component(.weekday, from: day)
            if request.preferences.enabledWeekdays.contains(weekday) {
                for minute in stride(from: request.preferences.activeStartHour * 60, to: request.preferences.activeEndHour * 60, by: request.preferences.intervalMinutes) {
                    guard let date = request.calendar.date(byAdding: .minute, value: minute, to: day), date > planningStart, date < request.horizon else { continue }
                    let exercise = selector.next(from: available, preferences: .init(), recentExerciseIDs: request.recentExerciseIDs, seed: stableSeed(date: date, state: request.state))!
                    result.append(PlannedReminder(id: "move.normal.\(Int(date.timeIntervalSince1970)).\(exercise.id)", fireDate: date, exerciseID: exercise.id, kind: .scheduled))
                    if result.count == request.maximumCount { break }
                }
            }
            guard let next = request.calendar.date(byAdding: .day, value: 1, to: day) else { break }; day = next
        }
        if let snoozeDate = request.state.snoozedReminderAt, snoozeDate > request.now, snoozeDate < request.horizon,
           request.calendar.isDate(snoozeDate, inSameDayAs: request.now),
           isAllowedSnoozeDate(snoozeDate, request: request),
           let exerciseID = request.state.snoozedExerciseID, available.contains(where: { $0.id == exerciseID }) {
            result.removeAll { abs($0.fireDate.timeIntervalSince(snoozeDate)) < 1 }
            result.append(.init(id: "move.snoozed.\(Int(snoozeDate.timeIntervalSince1970)).\(exerciseID)", fireDate: snoozeDate, exerciseID: exerciseID, kind: .snoozed))
        }
        return Array(result.sorted { $0.fireDate < $1.fireDate }.prefix(request.maximumCount))
    }
    private func isAllowedSnoozeDate(_ date: Date, request: ReminderPlanRequest) -> Bool {
        let start = request.calendar.startOfDay(for: request.now)
        guard let end = request.calendar.date(byAdding: .minute, value: request.preferences.activeEndHour * 60, to: start) else { return false }
        return date <= end.addingTimeInterval(60 * 60)
    }
    private func stableSeed(date: Date, state: ReminderState) -> Int {
        var value = UInt64(bitPattern: Int64(date.timeIntervalSince1970.rounded()))
        if let last = state.lastUserInteractionAt { value ^= UInt64(bitPattern: Int64(last.timeIntervalSince1970.rounded())) }
        return Int(truncatingIfNeeded: value ^ (value >> 32))
    }
}
