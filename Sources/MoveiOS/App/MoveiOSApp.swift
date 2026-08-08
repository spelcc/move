import SwiftUI
import SwiftData
import UserNotifications
import MoveCore
import MoveShared

@main struct MoveiOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let container: ModelContainer
    private let notificationDelegate: iOSNotificationDelegate
    @State private var store: iOSAppStore

    init() {
        let result = MoveModelContainer.makeWithFallback(schema: MoveSchemaV2.schema)
        container = result.container
        let appStore = iOSAppStore(context: result.container.mainContext)
        _store = State(initialValue: appStore)

        let delegate = iOSNotificationDelegate()
        notificationDelegate = delegate
        let done = UNNotificationAction(identifier: MoveNotificationContent.doneAction, title: "Terminé")
        let snooze = UNNotificationAction(identifier: MoveNotificationContent.snoozeAction, title: "Snooze")
        let skip = UNNotificationAction(
            identifier: MoveNotificationContent.skipAction,
            title: "Ignorer",
            options: [.destructive]
        )
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(
                identifier: MoveNotificationContent.categoryIdentifier,
                actions: [done, snooze, skip],
                intentIdentifiers: []
            )
        ])
        delegate.install { [weak appStore] intent in
            Task { @MainActor in appStore?.handle(intent) }
        }
        UNUserNotificationCenter.current().delegate = delegate
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(store: store)
                .task { store.scheduleReminders(debounce: .zero) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.scheduleReminders(debounce: .zero) }
                    else if phase == .background { store.workout.pauseIfRunning() }
                }
        }
        .modelContainer(container)
    }
}
