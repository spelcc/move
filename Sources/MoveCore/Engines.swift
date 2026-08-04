import Foundation

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
}

public struct Statistics: Equatable, Sendable {
    public var completedCount: Int
    public var totalRepetitions: Int
    public var activeSeconds: Int
    public var byExercise: [String: Int]
    public var activeDays: Int
    public var currentStreak: Int
}

public enum StatisticsService {
    public static func calculate(_ records: [ActivityRecord]) -> Statistics {
        let done = records.filter { $0.status == .completed }
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
        var streak = 0
        var day = Calendar.current.startOfDay(for: .now)
        while days.contains(day) {
            streak += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return .init(completedCount: done.count, totalRepetitions: reps, activeSeconds: seconds, byExercise: byExercise, activeDays: days.count, currentStreak: streak)
    }
}
