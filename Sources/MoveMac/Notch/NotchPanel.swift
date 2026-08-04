import AppKit
import SwiftUI
import MoveCore

enum NotchPanelState { case hidden, bumping, compact, expanded, success, skipped, snooze, workoutSuggestion, closing }

@MainActor final class NotchPanelController {
    private let panel: NSPanel
    init<Content: View>(rootView: Content) {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: rootView)
    }
    private(set) var state: NotchPanelState = .hidden

    func show(target: ReminderScreenTarget = .main, width: CGFloat = 460, height: CGFloat = 214) {
        guard let screen = targetScreen(target) else { return }
        state = .bumping
        let notch = screen.auxiliaryTopLeftArea.map { left in
            NSRect(x: left.maxX, y: screen.frame.maxY - 2, width: (screen.auxiliaryTopRightArea?.minX ?? left.maxX) - left.maxX, height: 2)
        }
        let anchor = notch?.midX ?? screen.frame.midX
        let x = min(max(anchor - width / 2, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - width - 8)
        // The panel is attached to the physical top edge. The content shape
        // supplies the soft, inverted corner instead of leaving a sharp gap.
        let y = screen.frame.maxY - height
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        panel.orderFrontRegardless()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) { state = .expanded }
    }

    private func targetScreen(_ target: ReminderScreenTarget) -> NSScreen? {
        let screens = NSScreen.screens
        switch target {
        case .main:
            return NSScreen.main ?? screens.first
        case .active:
            return screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main ?? screens.first
        case .macBook:
            return screens.first(where: { $0.auxiliaryTopLeftArea != nil && $0.auxiliaryTopRightArea != nil }) ?? NSScreen.main ?? screens.first
        }
    }
    func hide() { state = .closing; panel.orderOut(nil); state = .hidden }
}
