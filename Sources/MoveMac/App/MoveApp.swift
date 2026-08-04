import SwiftUI
import SwiftData
import MoveCore

@main struct MoveApp: App {
    private let container: ModelContainer
    @State private var store: MoveStore
    @State private var panel: NotchPanelController?
    init() {
        let container = try! ModelContainer(for: ActivityEntity.self)
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
        Settings { SettingsView(store: store).frame(width: 520, height: 420) }
    }
    private func showNotch() {
        let controller = NotchPanelController(rootView: NotchPromptView(store: store).modelContainer(container))
        panel = controller
        controller.show()
    }
}
