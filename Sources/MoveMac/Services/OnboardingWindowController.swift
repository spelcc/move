import SwiftUI
import SwiftData
import AppKit
import MoveCore

@MainActor
final class OnboardingWindowController {
    static let shared = OnboardingWindowController()

    private var window: NSWindow?
    private var panel: NotchPanelController?
    private var completionObserver: NSObjectProtocol?

    private init() {
        completionObserver = NotificationCenter.default.addObserver(
            forName: .moveOnboardingCompleted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.window?.close() }
        }
    }

    func showIfNeeded(store: MoveStore, container: ModelContainer) {
        guard !UserDefaults.standard.bool(forKey: "move.onboardingCompleted") else { return }
        show(store: store, container: container)
    }

    private func show(store: MoveStore, container: ModelContainer) {
        let root = OnboardingView(store: store) { [weak self] in
            self?.showNotch(store: store, container: container)
        }
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Bienvenue dans Move"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 460, height: 380))
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func showNotch(store: MoveStore, container: ModelContainer) {
        var controller: NotchPanelController?
        let root = NotchPromptView(
            store: store,
            onClose: { controller?.hide() },
            onResize: { width, height in controller?.resize(width: width, height: height) }
        ).modelContainer(container)
        controller = NotchPanelController(rootView: root)
        panel = controller
        controller?.show(target: store.appearance.screenTarget)
    }
}

extension Notification.Name {
    static let moveOnboardingCompleted = Notification.Name("Move.onboardingCompleted")
}
