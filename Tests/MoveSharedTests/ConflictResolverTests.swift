import Foundation
import Testing
import MoveCore
@testable import MoveShared

@Test func newestSettingsWinsConflict() {
    let old = SyncedSettingsSnapshot(updatedAt: Date(timeIntervalSince1970: 1), reminder: .init(), movement: .init(), appearance: .init())
    let new = SyncedSettingsSnapshot(updatedAt: Date(timeIntervalSince1970: 2), reminder: .init(), movement: .init(), appearance: .init())
    #expect(ConflictResolver.newestSettings([old, new]) == new)
}

@Test func activitiesAreDeduplicatedByUUID() {
    let id = UUID(); let old = ActivityRecord(id: id, exerciseID: "old", performedAt: Date(timeIntervalSince1970: 1), amount: 1, metric: .repetitions, status: .completed, source: .hourly)
    let new = ActivityRecord(id: id, exerciseID: "new", performedAt: Date(timeIntervalSince1970: 2), amount: 2, metric: .repetitions, status: .completed, source: .hourly)
    let result = ConflictResolver.deduplicatedActivities([new, old])
    #expect(result.count == 1); #expect(result[0].exerciseID == "new")
}
