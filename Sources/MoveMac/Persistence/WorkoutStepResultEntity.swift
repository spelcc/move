import Foundation
import SwiftData
import MoveCore

@Model final class WorkoutStepResultEntity {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    var stepID: UUID
    var exerciseID: String
    var round: Int
    var statusRaw: String
    var amount: Int
    var durationSeconds: Int
    var completedAt: Date

    init(sessionID: UUID, stepID: UUID, exerciseID: String, round: Int, status: ActivityStatus, amount: Int, durationSeconds: Int) {
        self.id = UUID(); self.sessionID = sessionID; self.stepID = stepID; self.exerciseID = exerciseID
        self.round = round; self.statusRaw = status.rawValue; self.amount = amount; self.durationSeconds = durationSeconds; self.completedAt = .now
    }
}
