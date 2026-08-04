import SwiftUI
import SwiftData
import AppKit
import UserNotifications
import MoveCore

@main struct MoveApp: App {
    private let container: ModelContainer
    private let notificationDelegate = MoveNotificationDelegate()
    @State private var store: MoveStore
    @State private var panel: NotchPanelController?
    @State private var persistenceError: String?
    init() {
        _persistenceError = State(initialValue: nil)
        ReminderNotificationService.configure()
        UNUserNotificationCenter.current().delegate = notificationDelegate
        let schema = MoveSchemaV1.schema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container: ModelContainer
        var persistenceIssue: String?
        do {
            container = try ModelContainer(for: schema, migrationPlan: MoveMigrationPlan.self, configurations: configuration)
        } catch {
            NSLog("Move persistence failed: %@", String(describing: error))
            persistenceIssue = String(describing: error)
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = (try? ModelContainer(for: schema, migrationPlan: MoveMigrationPlan.self, configurations: fallback)) ?? {
                fatalError("Unable to create Move storage")
            }()
        }
        _persistenceError = State(initialValue: persistenceIssue)
        self.container = container
        _store = State(initialValue: MoveStore(context: container.mainContext))
    }
    var body: some Scene {
        MenuBarExtra("Move", systemImage: "figure.run") {
            if persistenceError != nil {
                Label("Stockage local indisponible", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text("Les données de cette session ne survivront pas au redémarrage.")
                    .font(.caption)
                Divider()
            }
            if let pausedUntil = store.reminderState.pausedUntil, pausedUntil > .now {
                Label("Rappels en pause jusqu’à \(pausedUntil, style: .time)", systemImage: "pause.circle")
                    .foregroundStyle(.orange)
            } else if let next = store.reminderState.nextReminderAt {
                Text("Prochain rappel : \(next, style: .time)")
            }
            Button("Bouger maintenant") { showNotch() }
            Button("Séance 10 min") { store.start(ExerciseLibrary.quickWorkouts[1]) }
            Button("Pause 1 heure") { store.pauseReminders(until: .now.addingTimeInterval(3600)) }
            Button("Pause jusqu’à demain") {
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now)) ?? .now.addingTimeInterval(86400)
                store.pauseReminders(until: tomorrow)
            }
            Button(LaunchAtLoginService.isEnabled ? "Désactiver le lancement automatique" : "Lancer Move à la connexion") {
                try? LaunchAtLoginService.setEnabled(!LaunchAtLoginService.isEnabled)
            }
            Divider()
            SettingsLink { Text("Ouvrir Move") }
            Button("Quitter") { NSApplication.shared.terminate(nil) }
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
        let rootView = NotchPromptView(store: store, onClose: { controller?.hide() }, onResize: { width, height in
            controller?.resize(width: width, height: height)
        }).modelContainer(container)
        controller = NotchPanelController(rootView: rootView)
        panel = controller
        controller?.show(target: store.appearance.screenTarget)
    }
}
