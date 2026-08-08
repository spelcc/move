import SwiftUI
import SwiftData
import AppKit
import UserNotifications
import MoveCore
import MoveShared

@main struct MoveApp: App {
    private let container: ModelContainer
    private let notificationDelegate = MoveNotificationDelegate()
    @State private var store: MoveStore
    @State private var panel: NotchPanelController?
    @State private var persistenceError: String?
    @Environment(\.openWindow) private var openWindow
    init() {
        _persistenceError = State(initialValue: nil)
        ReminderNotificationService.configure()
        UNUserNotificationCenter.current().delegate = notificationDelegate
        let schema = MoveSchemaV2.schema
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .private(MoveModelContainer.cloudKitIdentifier))
        let container: ModelContainer
        var persistenceIssue: String?
        do {
            // V1 and V2 currently describe the same models. Passing the no-op
            // migration plan makes SwiftData construct an invalid lightweight
            // migration stage on macOS 27 and abort during app startup.
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            NSLog("Move persistence failed: %@", String(describing: error))
            persistenceIssue = String(describing: error)
            // A damaged or incompatible on-disk store must not prevent launch.
            // Keep this session usable and surface the persistence warning in
            // the menu while the durable store is unavailable.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = (try? ModelContainer(for: schema, configurations: fallback)) ?? {
                fatalError("Unable to create in-memory Move storage")
            }()
        }
        _persistenceError = State(initialValue: persistenceIssue)
        self.container = container
        let store = MoveStore(context: container.mainContext)
        _store = State(initialValue: store)
        DispatchQueue.main.async {
            OnboardingWindowController.shared.showIfNeeded(store: store, container: container)
        }
    }
    var body: some Scene {
        MenuBarExtra("Move", systemImage: "figure.run") {
            if persistenceError != nil {
                Label(MoveCopy.text("menu.storageUnavailable"), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(MoveCopy.text("menu.storageSessionOnly"))
                    .font(.caption)
                Divider()
            }
            if !ReminderHostPolicy.shouldSchedule(on: store.reminderHost, platform: .mac) {
                Label("Rappels programmés sur iPhone/Watch", systemImage: "iphone")
                    .foregroundStyle(.secondary)
            } else if store.notificationAuthorizationStatus == .denied {
                Label("Notifications macOS refusées", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else if let pausedUntil = store.reminderState.pausedUntil, pausedUntil > .now {
                Label(String(format: MoveCopy.text("menu.pausedUntil"), pausedUntil.formatted(date: .omitted, time: .shortened)), systemImage: "pause.circle")
                    .foregroundStyle(.orange)
            } else if let next = store.reminderState.nextReminderAt {
                Text(String(format: MoveCopy.text("menu.nextReminder"), next.formatted(date: .omitted, time: .shortened)))
            }
            Button(MoveCopy.text("menu.moveNow")) { showNotch() }
            Button(MoveCopy.text("menu.history")) {
                store.selectedTab = "Historique"
                openDashboard()
            }
            Button(MoveCopy.text("menu.workout10")) {
                store.selectedTab = "Séances"
                openDashboard()
            }
            Button(MoveCopy.text("menu.pauseHour")) { store.pauseReminders(until: .now.addingTimeInterval(3600)) }
            Button(MoveCopy.text("menu.pauseTomorrow")) {
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now.addingTimeInterval(86400)
                store.pauseReminders(until: tomorrow)
            }
            Button(LaunchAtLoginService.isEnabled ? MoveCopy.text("menu.disableLaunch") : MoveCopy.text("menu.enableLaunch")) {
                try? LaunchAtLoginService.setEnabled(!LaunchAtLoginService.isEnabled)
            }
            Divider()
            Button(MoveCopy.text("menu.settings")) {
                store.selectedTab = "Réglages"
                openDashboard()
            }
            Button(MoveCopy.text("menu.quit")) { NSApplication.shared.terminate(nil) }
        }
        Window("Move", id: "dashboard") { DashboardView(store: store).modelContainer(container) }
        Window("Bienvenue dans Move", id: "onboarding") { OnboardingView(store: store) { showNotch() } }
        Settings { SettingsView(store: store).frame(width: 520, height: 420) }
            .commands {
                CommandMenu("Move") {
                    Button("Bouger maintenant") { showNotch() }.keyboardShortcut("b", modifiers: [.command, .option])
                    Button("Ouvrir Move") { NSApp.activate(ignoringOtherApps: true) }.keyboardShortcut("m", modifiers: [.command, .option])
                }
            }
    }
    private func showNotch() {
        var controller: NotchPanelController?
        let rootView = NotchPromptView(store: store, onClose: { controller?.hide() }).modelContainer(container)
        controller = NotchPanelController(rootView: rootView)
        panel = controller
        controller?.show(target: store.appearance.screenTarget)
    }

    private func openDashboard() {
        openWindow(id: "dashboard")
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first(where: { $0.title == "Move" })?.makeKeyAndOrderFront(nil)
        }
    }
}
