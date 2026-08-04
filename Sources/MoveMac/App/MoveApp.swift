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
        let schema = Schema([ActivityEntity.self, AppSettingsEntity.self, CustomExerciseEntity.self])
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
            Button("Bouger maintenant") { showNotch() }
            Button("Séance 10 min") { store.start(ExerciseLibrary.quickWorkouts[1]) }
            Divider()
            SettingsLink { Text("Ouvrir Move") }
            Button("Quitter") { NSApplication.shared.terminate(nil) }
        }
        Window("Move", id: "dashboard") { DashboardView(store: store).modelContainer(container) }
        Window("Bienvenue dans Move", id: "onboarding") { OnboardingView() }
        Settings { SettingsView(store: store).frame(width: 520, height: 420) }
    }
    private func showNotch() {
        let controller = NotchPanelController(rootView: NotchPromptView(store: store).modelContainer(container))
        panel = controller
        controller.show()
    }
}
