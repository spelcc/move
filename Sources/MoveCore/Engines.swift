import Foundation

public enum ReminderDeliveryPolicy {
    /// Returns whether a reminder may be presented in the current context.
    /// The two preferences are independent: either disabled context suppresses delivery.
    public static func shouldDeliver(isFullScreen: Bool, isMeeting: Bool,
                                     preferences: ReminderPreferences) -> Bool {
        if isFullScreen && !preferences.notificationsDuringFullScreen { return false }
        if isMeeting && !preferences.notificationsDuringMeetings { return false }
        return true
    }
}

public enum WorkoutSoundCue: Sendable { case start, countdown, change, end }

public enum WorkoutSoundPolicy {
    public static func shouldPlay(_ cue: WorkoutSoundCue, mode: SoundMode) -> Bool {
        switch mode {
        case .off: return false
        case .discreet: return cue == .start || cue == .change || cue == .end
        case .normal: return true
        }
    }
}

public struct ExerciseSelector: Sendable {
    public init() {}
    public func candidates(from exercises: [Exercise], preferences: MovementPreferences) -> [Exercise] {
        exercises.filter { exercise in
            !preferences.disabledExerciseIDs.contains(exercise.id)
            && exercise.equipment.isSubset(of: preferences.availableEquipment)
            && exercise.tags.isDisjoint(with: preferences.excludedTags)
            && preferences.preferredDifficulty.contains(exercise.difficulty)
        }
    }
    public func next(from exercises: [Exercise], preferences: MovementPreferences, recentExerciseIDs: [String], seed: Int = Int.random(in: 0...Int.max)) -> Exercise? {
        let available = candidates(from: exercises, preferences: preferences)
        let fresh = available.filter { !recentExerciseIDs.suffix(3).contains($0.id) }
        let pool = fresh.isEmpty ? available : fresh
        guard !pool.isEmpty else { return nil }
        return pool[abs(seed) % pool.count]
    }

    public func adapted(_ exercise: Exercise, from exercises: [Exercise], refusals: Int, easyCompletions: Int) -> Exercise {
        let targetID = refusals >= 2 ? exercise.easierVariantID : (easyCompletions >= 3 ? exercise.harderVariantID : nil)
        guard let targetID, var variant = exercises.first(where: { $0.id == targetID }) else { return exercise }
        if refusals >= 2 { variant.defaultAmount = max(1, variant.defaultAmount - 2) }
        if easyCompletions >= 3 { variant.defaultAmount += 2 }
        return variant
    }
}

public struct ReminderScheduler: Sendable {
    public init() {}
    public func nextDate(after date: Date, preferences: ReminderPreferences, calendar: Calendar = .current) -> Date? {
        guard preferences.enabled else { return nil }
        guard preferences.intervalMinutes >= 15, preferences.intervalMinutes <= 180,
              preferences.activeStartHour < preferences.activeEndHour else { return nil }
        for offset in 1...(8 * 24 * 60) {
            guard let candidate = calendar.date(byAdding: .minute, value: offset, to: date) else { continue }
            let weekday = calendar.component(.weekday, from: candidate)
            let hour = calendar.component(.hour, from: candidate)
            let minuteDistance = Int(candidate.timeIntervalSince(date) / 60)
            guard preferences.enabledWeekdays.contains(weekday), hour >= preferences.activeStartHour, hour < preferences.activeEndHour else { continue }
            if minuteDistance >= preferences.intervalMinutes { return candidate }
        }
        return nil
    }

    public func nextDate(now: Date, preferences: ReminderPreferences, state: ReminderState,
                         calendar: Calendar = .current) -> Date? {
        if let pausedUntil = state.pausedUntil, pausedUntil > now { return pausedUntil }
        return nextDate(after: max(now, state.lastReminderAt ?? now), preferences: preferences, calendar: calendar)
    }

    /// Recomputes one normal reminder after wake, never replaying all reminders
    /// that would have elapsed while the Mac was asleep.
    public func nextDateAfterWake(now: Date, preferences: ReminderPreferences, state: ReminderState,
                                  wakeDelay: TimeInterval = 60, calendar: Calendar = .current) -> Date? {
        let eligibleAt = now.addingTimeInterval(max(30, min(wakeDelay, 90)))
        var refreshed = state
        refreshed.lastReminderAt = max(state.lastReminderAt ?? .distantPast, eligibleAt)
        refreshed.pausedUntil = nil
        return nextDate(now: eligibleAt, preferences: preferences, state: refreshed, calendar: calendar)
    }
}

public struct Statistics: Equatable, Sendable {
    public var completedCount: Int
    public var acceptedReminderCount: Int
    public var skippedCount: Int
    public var snoozedCount: Int
    public var completedWorkoutCount: Int
    public var totalRepetitions: Int
    public var activeSeconds: Int
    public var byExercise: [String: Int]
    public var activeDays: Int
    public var currentStreak: Int
    public var bestDayCompletedCount: Int
    public var longestStreak: Int
}

public struct ExerciseStatistics: Equatable, Sendable, Identifiable {
    public let id: String
    public var completedCount: Int
    public var totalAmount: Int
    public var bestDayAmount: Int
    public var lastPerformedAt: Date?
}

public enum StatisticsService {
    public static func calculate(_ records: [ActivityRecord]) -> Statistics {
        let done = records.filter { $0.status == .completed }
        let skipped = records.filter { $0.status == .skipped }.count
        let snoozed = records.filter { $0.status == .snoozed }.count
        let acceptedReminders = done.filter { $0.source == .hourly }.count
        let completedWorkouts = Set(done.compactMap { (record: ActivityRecord) -> UUID? in
            guard record.source == .quickWorkout || record.source == .customWorkout else { return nil }
            return record.workoutID
        }).count
        var reps = 0, seconds = 0, byExercise: [String: Int] = [:]
        for record in done {
            byExercise[record.exerciseID, default: 0] += record.amount
            switch record.metric {
            case .repetitions: reps += record.amount
            case .seconds: seconds += record.amount
            case .minutes: seconds += record.amount * 60
            case .free: break
            }
        }
        let days = Set(done.map { Calendar.current.startOfDay(for: $0.performedAt) })
        let calendar = Calendar.current
        var dailyCounts: [Date: Int] = [:]
        for record in done { dailyCounts[calendar.startOfDay(for: record.performedAt), default: 0] += 1 }
        let bestDay = dailyCounts.values.max() ?? 0
        var streak = 0
        var day = calendar.startOfDay(for: .now)
        if !days.contains(day), let yesterday = calendar.date(byAdding: .day, value: -1, to: day), days.contains(yesterday) { day = yesterday }
        while days.contains(day) {
            streak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        var longest = 0
        for candidate in days {
            let previous = calendar.date(byAdding: .day, value: -1, to: candidate)
            if let previous, days.contains(previous) { continue }
            var length = 0; var cursor = candidate
            while days.contains(cursor) { length += 1; guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }; cursor = next }
            longest = max(longest, length)
        }
        return .init(completedCount: done.count, acceptedReminderCount: acceptedReminders, skippedCount: skipped, snoozedCount: snoozed, completedWorkoutCount: completedWorkouts, totalRepetitions: reps, activeSeconds: seconds, byExercise: byExercise, activeDays: days.count, currentStreak: streak, bestDayCompletedCount: bestDay, longestStreak: longest)
    }

    public static func calculate(_ records: [ActivityRecord], since start: Date, until end: Date = .now) -> Statistics {
        calculate(records.filter { $0.performedAt >= start && $0.performedAt <= end })
    }

    public static func currentWeek(_ records: [ActivityRecord], calendar: Calendar = .current, now: Date = .now) -> Statistics {
        let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return calculate(records, since: start, until: now)
    }

    public static func forExercise(_ records: [ActivityRecord], exerciseID: String) -> ExerciseStatistics {
        let matching = records.filter { $0.exerciseID == exerciseID && $0.status == .completed }
        let calendar = Calendar.current
        var daily: [Date: Int] = [:]
        for record in matching { daily[calendar.startOfDay(for: record.performedAt), default: 0] += record.amount }
        return .init(id: exerciseID, completedCount: matching.count, totalAmount: matching.reduce(0) { $0 + $1.amount }, bestDayAmount: daily.values.max() ?? 0, lastPerformedAt: matching.map(\.performedAt).max())
    }
}
