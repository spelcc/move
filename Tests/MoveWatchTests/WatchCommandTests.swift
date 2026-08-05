import Foundation
import Testing
import MoveShared

@Test func watchCommandRoundTripsThroughCodable() throws {
    let command = WatchCommand(action: .snooze, reminderID: "move.normal.1.squats")
    let decoded = try JSONDecoder().decode(WatchCommand.self, from: JSONEncoder().encode(command))
    #expect(decoded == command)
}
