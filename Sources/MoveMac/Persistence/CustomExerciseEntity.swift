import Foundation
import SwiftData
import MoveCore

@Model final class CustomExerciseEntity {
    var id: String
    var name: String
    var emoji: String
    var categoryRaw: String
    var metricRaw: String
    var defaultAmount: Int
    var archived: Bool
    var instructions: String
    var equipmentRaw: String = ""
    var tagsRaw: String = ""
    var muscleZonesRaw: String = ""
    var createdAt: Date
    var updatedAt: Date

    init(name: String, emoji: String = "💪", category: ExerciseCategory = .strength,
         metric: ExerciseMetric = .repetitions, defaultAmount: Int = 10, instructions: String = "",
         equipment: Set<String> = [], tags: Set<String> = [], muscleZones: Set<String> = []) {
        id = "custom-\(UUID().uuidString)"; self.name = name; self.emoji = emoji
        categoryRaw = category.rawValue; metricRaw = metric.rawValue; self.defaultAmount = defaultAmount
        archived = false; self.instructions = instructions
        equipmentRaw = equipment.sorted().joined(separator: ",")
        tagsRaw = tags.sorted().joined(separator: ",")
        muscleZonesRaw = muscleZones.sorted().joined(separator: ",")
        createdAt = .now; updatedAt = .now
    }

    var exercise: Exercise? {
        guard let category = ExerciseCategory(rawValue: categoryRaw),
              let metric = ExerciseMetric(rawValue: metricRaw) else { return nil }
        let difficulty = tags.compactMap { $0.hasPrefix("difficulty-") ? Int(String($0.dropFirst("difficulty-".count))) : nil }.first ?? 1
        let easierVariantID = tags.first(where: { $0.hasPrefix("easier-") }).map { String($0.dropFirst("easier-".count)) }
        let harderVariantID = tags.first(where: { $0.hasPrefix("harder-") }).map { String($0.dropFirst("harder-".count)) }
        return Exercise(id: id, name: name, category: category, metric: metric,
                        defaultAmount: max(0, defaultAmount), difficulty: min(3, max(1, difficulty)), equipment: equipment,
                        tags: tags.union(muscleZones.map { "zone-\($0)" }).union(["personnalisé"]),
                        emoji: emoji, easierVariantID: easierVariantID, harderVariantID: harderVariantID)
    }

    var equipment: Set<String> { Set(equipmentRaw.split(separator: ",").map(String.init)) }
    var tags: Set<String> { Set(tagsRaw.split(separator: ",").map(String.init)) }
    var muscleZones: Set<String> { Set(muscleZonesRaw.split(separator: ",").map(String.init)) }
}
