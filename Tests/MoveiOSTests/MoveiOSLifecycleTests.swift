import Foundation
import Testing
import UserNotifications
import MoveCore
@testable import MoveiOS

@Test func iOSDefaultsToPhoneAndWatchHost() {
    #expect(ReminderHostPreference.phoneAndWatch == .phoneAndWatch)
}

@Test func notificationTapRoutesToRequestedExercise() {
    let intent = iOSNotificationIntent(
        actionIdentifier: UNNotificationDefaultActionIdentifier,
        exerciseID: "squats"
    )
    let route = iOSNotificationRouting.route(for: intent, validExerciseIDs: ["squats"])
    #expect(route == .today(exerciseID: "squats"))
}

@Test func unknownNotificationExerciseFallsBackSafely() {
    let intent = iOSNotificationIntent(
        actionIdentifier: UNNotificationDefaultActionIdentifier,
        exerciseID: "missing"
    )
    let route = iOSNotificationRouting.route(for: intent, validExerciseIDs: ["squats"])
    #expect(route == .today(exerciseID: nil))
}

@Test func notificationDelegateBuffersColdLaunchIntent() {
    let delegate = iOSNotificationDelegate()
    let intent = iOSNotificationIntent(
        actionIdentifier: UNNotificationDefaultActionIdentifier,
        exerciseID: "plank"
    )
    let box = IntentBox()
    delegate.receive(intent)
    delegate.install { box.value = $0 }
    #expect(box.value == intent)
}

@Test func notificationResponseCompletesSynchronously() {
    let delegate = iOSNotificationDelegate()
    let box = IntentBox()
    let completion = CompletionBox()
    delegate.install { box.value = $0 }

    delegate.handleResponse(
        actionIdentifier: UNNotificationDefaultActionIdentifier,
        exerciseID: "plank"
    ) {
        completion.called = true
    }

    #expect(box.value?.exerciseID == "plank")
    #expect(completion.called)
}

private final class IntentBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: iOSNotificationIntent?
    var value: iOSNotificationIntent? {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

private final class CompletionBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored = false
    var called: Bool {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}
