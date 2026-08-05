import Foundation
import SwiftData
import MoveCore

@Model final class WorkoutTemplateEntity {
    var id: UUID
    var name: String
    var templateData: Data
    var archived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(template: WorkoutTemplate) {
        id = template.id; name = template.name
        templateData = (try? JSONEncoder().encode(template)) ?? Data()
        archived = false; createdAt = .now; updatedAt = .now
    }

    var template: WorkoutTemplate? { try? JSONDecoder().decode(WorkoutTemplate.self, from: templateData) }
}
