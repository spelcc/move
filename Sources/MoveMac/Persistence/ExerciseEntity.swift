import Foundation
import SwiftData

@Model final class ExerciseEntity {
    var id: String
    var name: String
    var categoryRaw: String
    var metricRaw: String
    var defaultAmount: Int
    var archived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(id: String, name: String, categoryRaw: String, metricRaw: String, defaultAmount: Int, archived: Bool = false) {
        self.id = id; self.name = name; self.categoryRaw = categoryRaw; self.metricRaw = metricRaw
        self.defaultAmount = defaultAmount; self.archived = archived; self.createdAt = .now; self.updatedAt = .now
    }
}
