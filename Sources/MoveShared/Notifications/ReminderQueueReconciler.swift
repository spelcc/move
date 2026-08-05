import Foundation
import MoveCore

public struct ReminderQueueReconciler: Sendable {
    private let client: any NotificationClient
    public init(client: any NotificationClient) { self.client = client }

    public func reconcile(plan: [PlannedReminder]) async throws {
        let pending = await client.pending()
        let moveIDs = Set(pending.map(\.id).filter { $0.hasPrefix("move.") })
        let desired = Set(plan.map(\.id))
        let stale = moveIDs.subtracting(desired)
        if !stale.isEmpty { await client.remove(ids: Array(stale)) }
        let existing = Set(pending.map(\.id))
        let missing = plan.filter { !existing.contains($0.id) }
        if !missing.isEmpty { try await client.schedule(missing) }
    }
}
