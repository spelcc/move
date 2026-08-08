import Foundation

struct iOSMovementTimerMachine: Equatable {
    enum Phase: Equatable, Hashable {
        case idle
        case running
        case paused
        case completed
    }

    let durationSeconds: Int
    private(set) var phase: Phase = .idle
    private(set) var remainingSeconds: Int
    private(set) var completionWasConsumed = false
    private var deadline: Date?

    init(durationSeconds: Int) {
        let duration = max(1, durationSeconds)
        self.durationSeconds = duration
        remainingSeconds = duration
    }

    var progress: Double {
        1 - (Double(remainingSeconds) / Double(durationSeconds))
    }

    mutating func start(at date: Date = .now) {
        guard phase == .idle else { return }
        remainingSeconds = durationSeconds
        deadline = date.addingTimeInterval(TimeInterval(durationSeconds))
        completionWasConsumed = false
        phase = .running
    }

    mutating func tick(at date: Date = .now) {
        guard phase == .running, let deadline else { return }
        remainingSeconds = max(0, Int(ceil(deadline.timeIntervalSince(date))))
        if remainingSeconds == 0 {
            self.deadline = nil
            phase = .completed
        }
    }

    mutating func pause(at date: Date = .now) {
        guard phase == .running else { return }
        tick(at: date)
        guard phase == .running else { return }
        deadline = nil
        phase = .paused
    }

    mutating func resume(at date: Date = .now) {
        guard phase == .paused else { return }
        deadline = date.addingTimeInterval(TimeInterval(remainingSeconds))
        phase = .running
    }

    mutating func cancel() {
        deadline = nil
        remainingSeconds = durationSeconds
        completionWasConsumed = false
        phase = .idle
    }

    mutating func consumeCompletion() -> Bool {
        guard phase == .completed, !completionWasConsumed else { return false }
        completionWasConsumed = true
        return true
    }
}
