import Foundation
import UserNotifications

struct iOSNotificationIntent: Sendable, Equatable {
    let actionIdentifier: String
    let exerciseID: String?
}

final class iOSNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var pendingIntent: iOSNotificationIntent?
    private var handler: (@Sendable (iOSNotificationIntent) -> Void)?

    func install(handler: @escaping @Sendable (iOSNotificationIntent) -> Void) {
        let pending = lock.withLock {
            self.handler = handler
            let pending = pendingIntent
            pendingIntent = nil
            return pending
        }
        if let pending { handler(pending) }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        handleResponse(
            actionIdentifier: response.actionIdentifier,
            exerciseID: response.notification.request.content.userInfo["exerciseID"] as? String,
            completionHandler: completionHandler
        )
    }

    func handleResponse(
        actionIdentifier: String,
        exerciseID: String?,
        completionHandler: @escaping @Sendable () -> Void
    ) {
        receive(iOSNotificationIntent(
            actionIdentifier: actionIdentifier,
            exerciseID: exerciseID
        ))
        completionHandler()
    }

    func receive(_ intent: iOSNotificationIntent) {
        let currentHandler = lock.withLock {
            let currentHandler = handler
            if currentHandler == nil { pendingIntent = intent }
            return currentHandler
        }
        currentHandler?(intent)
    }
}
