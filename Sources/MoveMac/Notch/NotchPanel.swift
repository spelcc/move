import AppKit
import SwiftUI
import MoveCore

enum NotchPanelState { case hidden, bumping, compact, expanded, success, skipped, snooze, workoutSuggestion, closing }

@MainActor final class NotchPanelController {
    private let panel: NSPanel
    private var screenChangeObserver: NSObjectProtocol?
    private var target: ReminderScreenTarget = .main
    init<Content: View>(rootView: Content) {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: rootView)
        screenChangeObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.repositionOnScreenChange() }
        }
    }

    private(set) var state: NotchPanelState = .hidden

    func show(target: ReminderScreenTarget = .main, width: CGFloat = 236, height: CGFloat = 72) {
        self.target = target
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
        state = .compact
        resize(width: 460, height: 214, on: screen, anchor: anchor, animated: true) { [weak self] in self?.state = .expanded }
    }

    private func repositionOnScreenChange() {
        guard state != .hidden, let screen = targetScreen(target) else { return }
        let frame = panel.frame
        let anchor = screen.auxiliaryTopLeftArea.map { left in
            (left.maxX + (screen.auxiliaryTopRightArea?.minX ?? left.maxX)) / 2
        } ?? screen.frame.midX
        let x = min(max(anchor - frame.width / 2, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - frame.width - 8)
        let updated = NSRect(x: x, y: screen.frame.maxY - frame.height, width: frame.width, height: frame.height)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            panel.animator().setFrame(updated, display: true)
        }
    }

    func resize(width: CGFloat, height: CGFloat, animated: Bool = true, completion: (() -> Void)? = nil) {
        guard let screen = panel.screen ?? NSScreen.main else { completion?(); return }
        let anchor = screen.auxiliaryTopLeftArea.map { left in
            (left.maxX + (screen.auxiliaryTopRightArea?.minX ?? left.maxX)) / 2
        } ?? screen.frame.midX
        resize(width: width, height: height, on: screen, anchor: anchor, animated: animated, completion: completion)
    }

    private func resize(width: CGFloat, height: CGFloat, on screen: NSScreen, anchor: CGFloat, animated: Bool, completion: (() -> Void)? = nil) {
        let x = min(max(anchor - width / 2, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - width - 8)
        let frame = NSRect(x: x, y: screen.frame.maxY - height, width: width, height: height)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.42
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(frame, display: true)
            } completionHandler: { completion?() }
        } else { panel.setFrame(frame, display: true); completion?() }
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
    func hide() {
        state = .closing
        resize(width: 184, height: 52) { [weak self] in
            self?.panel.orderOut(nil); self?.state = .hidden
        }
    }
}
