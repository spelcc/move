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
    @AppStorage("move.onboardingCompleted") private var onboardingCompleted = false
    init() {
        ReminderNotificationService.configure()
        UNUserNotificationCenter.current().delegate = notificationDelegate
        let schema = Schema([ActivityEntity.self, AppSettingsEntity.self, CustomExerciseEntity.self, WorkoutSessionEntity.self, WorkoutTemplateEntity.self, ReminderStateEntity.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            NSLog("Move persistence failed: %@", String(describing: error))
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            container = (try? ModelContainer(for: schema, configurations: fallback)) ?? {
                fatalError("Unable to create Move storage")
            }()
        }
        self.container = container
        _store = State(initialValue: MoveStore(context: container.mainContext))
    }
    var body: some Scene {
        MenuBarExtra("Move", systemImage: "figure.run") {
            if let next = store.reminderState.nextReminderAt { Text("Prochain rappel : \(next, style: .time)") }
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
        Window("Bienvenue dans Move", id: "onboarding") { OnboardingView { showNotch() } }
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
        controller?.show()
    }
}
