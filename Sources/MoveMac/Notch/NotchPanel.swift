import AppKit
import SwiftUI

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

    func show(width: CGFloat = 420, height: CGFloat = 150) {
        guard let screen = targetScreen() else { return }
        state = .bumping
        let notch = screen.auxiliaryTopLeftArea.map { left in
            NSRect(x: left.maxX, y: screen.frame.maxY - 2, width: (screen.auxiliaryTopRightArea?.minX ?? left.maxX) - left.maxX, height: 2)
        }
        let anchor = notch?.midX ?? screen.frame.midX
        let x = min(max(anchor - width / 2, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - width - 8)
        let y = screen.frame.maxY - height - 4
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        panel.orderFrontRegardless()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) { state = .expanded }
    }

    private func targetScreen() -> NSScreen? {
        if let main = NSScreen.main { return main }
        return NSScreen.screens.first
    }
    func hide() { state = .closing; panel.orderOut(nil); state = .hidden }
}
