import Testing
import Foundation
@testable import MoveShared

@Test func watchCommandsAreIdempotent() async {
    let queue = WatchCommandQueue(); let id = UUID(); let command = WatchCommand(commandID: id, action: .done)
    await queue.enqueue(command); await queue.enqueue(command)
    #expect((await queue.drain()).count == 1)
    await queue.enqueue(command)
    #expect((await queue.drain()).isEmpty)
}
