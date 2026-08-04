import Foundation
import SwiftData
import MoveCore

@Model final class CustomExerciseEntity {
    @Attribute(.unique) var id: String
    var name: String
    var emoji: String
    var categoryRaw: String
    var metricRaw: String
    var defaultAmount: Int
    var archived: Bool
    var instructions: String
    var createdAt: Date
    var updatedAt: Date

    init(name: String, emoji: String = "💪", category: ExerciseCategory = .strength,
         metric: ExerciseMetric = .repetitions, defaultAmount: Int = 10, instructions: String = "") {
        id = "custom-\(UUID().uuidString)"; self.name = name; self.emoji = emoji
        categoryRaw = category.rawValue; metricRaw = metric.rawValue; self.defaultAmount = defaultAmount
        archived = false; self.instructions = instructions; createdAt = .now; updatedAt = .now
    }

    var exercise: Exercise? {
        guard let category = ExerciseCategory(rawValue: categoryRaw),
              let metric = ExerciseMetric(rawValue: metricRaw) else { return nil }
        return Exercise(id: id, name: name, category: category, metric: metric,
                        defaultAmount: max(0, defaultAmount), tags: ["personnalisé"],
                        emoji: emoji)
    }
}
