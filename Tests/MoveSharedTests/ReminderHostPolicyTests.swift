import Testing
import MoveCore
@testable import MoveShared

@Test func hostPolicyAvoidsMacDuplicateByDefault() {
    #expect(!ReminderHostPolicy.shouldSchedule(on: .phoneAndWatch, platform: .mac))
    #expect(ReminderHostPolicy.shouldSchedule(on: .phoneAndWatch, platform: .phone))
    #expect(ReminderHostPolicy.shouldSchedule(on: .all, platform: .mac))
}
