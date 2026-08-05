import SwiftUI
import MoveCore
import MoveShared
import UserNotifications

@main struct MoveiOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let coordinator = iOSReminderCoordinator()
    private let notificationDelegate = iOSNotificationDelegate()
    init() {
        let done = UNNotificationAction(identifier: MoveNotificationContent.doneAction, title: "Terminé")
        let snooze = UNNotificationAction(identifier: MoveNotificationContent.snoozeAction, title: "Snooze")
        let skip = UNNotificationAction(identifier: MoveNotificationContent.skipAction, title: "Ignorer", options: [.destructive])
        UNUserNotificationCenter.current().setNotificationCategories([UNNotificationCategory(identifier: MoveNotificationContent.categoryIdentifier, actions: [done, snooze, skip], intentIdentifiers: [])])
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }
    var body: some Scene { WindowGroup { RootTabView(requestAuthorization: { await coordinator.requestAuthorization() }).task { await coordinator.reconcile() }.onChange(of: scenePhase) { _, phase in if phase == .active { Task { await coordinator.reconcile() } } } } }
}
