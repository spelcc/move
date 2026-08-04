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
}
