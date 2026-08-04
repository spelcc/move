import Foundation
import SwiftData
import MoveCore

@Model final class ActivityEntity {
    @Attribute(.unique) var id: UUID
    var exerciseID: String
    var performedAt: Date
    var amount: Int
    var metricRaw: String
    var statusRaw: String
    var sourceRaw: String
    var workoutID: UUID?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    init(record: ActivityRecord) {
        id = record.id; exerciseID = record.exerciseID; performedAt = record.performedAt; amount = record.amount
        metricRaw = record.metric.rawValue; statusRaw = record.status.rawValue; sourceRaw = record.source.rawValue
        workoutID = record.workoutID
        createdAt = record.performedAt; updatedAt = .now
    }
    var record: ActivityRecord {
        .init(id: id, exerciseID: exerciseID, performedAt: performedAt, amount: amount, metric: ExerciseMetric(rawValue: metricRaw) ?? .free, status: ActivityStatus(rawValue: statusRaw) ?? .completed, source: ActivitySource(rawValue: sourceRaw) ?? .hourly, workoutID: workoutID)
    }

    func update(amount: Int, status: ActivityStatus? = nil) {
        self.amount = max(0, amount)
        if let status { statusRaw = status.rawValue }
        updatedAt = .now
    }
}
