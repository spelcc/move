import Foundation
import Testing
import MoveCore
@testable import MoveShared

private actor FakeClient: NotificationClient {
    var requests: [PendingNotification]
    init(_ requests: [PendingNotification] = []) { self.requests = requests }
    func requestAuthorization() async throws -> Bool { true }
    func pending() async -> [PendingNotification] { requests }
    func schedule(_ reminders: [PlannedReminder]) async throws { requests += reminders.map { .init(id: $0.id, fireDate: $0.fireDate) } }
    func remove(ids: [String]) async { requests.removeAll { ids.contains($0.id) } }
}

@Test func reconcilerKeepsForeignNotificationsAndRemovesStaleMoveRequests() async throws {
    let client = FakeClient([.init(id: "move.old", fireDate: .now), .init(id: "other.app", fireDate: .now)])
    let plan = [PlannedReminder(id: "move.new", fireDate: .now.addingTimeInterval(60), exerciseID: "squats", kind: .scheduled)]
    try await ReminderQueueReconciler(client: client).reconcile(plan: plan)
    let pending = await client.pending()
    #expect(pending.map(\.id).sorted() == ["move.new", "other.app"])
}

@Test func reconcilerIsIdempotent() async throws {
    let client = FakeClient()
    let plan = [PlannedReminder(id: "move.one", fireDate: .now, exerciseID: "squats", kind: .scheduled)]
    let reconciler = ReminderQueueReconciler(client: client)
    try await reconciler.reconcile(plan: plan); try await reconciler.reconcile(plan: plan)
    #expect((await client.pending()).count == 1)
}
