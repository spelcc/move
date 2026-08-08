import Foundation
import Testing
@testable import MoveShared

@Test func cloudSyncMonitorDebouncesEvents() async {
    let monitor = CloudSyncMonitor()
    let values = LockedEvents()
    _ = await monitor.observe { event in values.append(event) }
    await monitor.emit(.remoteChange, debounceNanoseconds: 1_000_000)
    await monitor.emit(.remoteChange, debounceNanoseconds: 1_000_000)
    try? await Task.sleep(nanoseconds: 20_000_000)
    #expect(values.count == 1)
}

private final class LockedEvents: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [CloudSyncMonitor.Event] = []
    func append(_ value: CloudSyncMonitor.Event) { lock.lock(); storage.append(value); lock.unlock() }
    var count: Int { lock.lock(); defer { lock.unlock() }; return storage.count }
}
