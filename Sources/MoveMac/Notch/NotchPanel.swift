import AppKit
import SwiftUI

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
    func show(width: CGFloat = 420, height: CGFloat = 150) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main else { return }
        let x = screen.frame.midX - width / 2
        let y = screen.frame.maxY - height - 4
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        panel.orderFrontRegardless()
    }
    func hide() { panel.orderOut(nil) }
}
