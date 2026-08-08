import Foundation
import Testing
@testable import MoveiOS

@Test func movementTimerPausesAndResumesFromRemainingTime() {
    let start = Date(timeIntervalSince1970: 1_000)
    var timer = iOSMovementTimerMachine(durationSeconds: 30)

    timer.start(at: start)
    timer.pause(at: start.addingTimeInterval(11))

    #expect(timer.phase == .paused)
    #expect(timer.remainingSeconds == 19)

    timer.resume(at: start.addingTimeInterval(100))
    timer.tick(at: start.addingTimeInterval(105))

    #expect(timer.phase == .running)
    #expect(timer.remainingSeconds == 14)
}

@Test func movementTimerCatchesUpAfterBackgroundGap() {
    let start = Date(timeIntervalSince1970: 2_000)
    var timer = iOSMovementTimerMachine(durationSeconds: 10)

    timer.start(at: start)
    timer.tick(at: start.addingTimeInterval(15))

    #expect(timer.phase == .completed)
    #expect(timer.remainingSeconds == 0)
    #expect(timer.progress == 1)
}

@Test func movementTimerCompletionCanOnlyBeConsumedOnce() {
    let start = Date(timeIntervalSince1970: 3_000)
    var timer = iOSMovementTimerMachine(durationSeconds: 1)

    timer.start(at: start)
    timer.tick(at: start.addingTimeInterval(1))

    let firstConsumption = timer.consumeCompletion()
    let secondConsumption = timer.consumeCompletion()
    #expect(firstConsumption)
    #expect(!secondConsumption)
}

@Test func cancellingMovementTimerRestoresIdleState() {
    var timer = iOSMovementTimerMachine(durationSeconds: 20)

    timer.start(at: Date(timeIntervalSince1970: 4_000))
    timer.cancel()

    #expect(timer.phase == .idle)
    #expect(timer.remainingSeconds == 20)
    #expect(timer.progress == 0)
}
