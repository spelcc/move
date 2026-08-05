import Foundation

public actor CloudSyncMonitor {
    public enum Event: Sendable { case localChange, remoteChange }
    private var observers: [UUID: @Sendable (Event) -> Void] = [:]
    private var pendingTask: Task<Void, Never>?
    public init() {}
    public func observe(_ handler: @escaping @Sendable (Event) -> Void) -> UUID {
        let id = UUID(); observers[id] = handler; return id
    }
    public func remove(_ id: UUID) { observers.removeValue(forKey: id) }
    public func emit(_ event: Event, debounceNanoseconds: UInt64 = 250_000_000) {
        pendingTask?.cancel()
        let handlers = Array(observers.values)
        pendingTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: debounceNanoseconds)
            guard !Task.isCancelled else { return }
            for handler in handlers { handler(event) }
            await self?.clearTask()
        }
    }
    private func clearTask() { pendingTask = nil }
}
