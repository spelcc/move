import AppKit
import SwiftUI
import MoveCore

enum NotchPanelState { case hidden, bumping, compact, expanded, success, skipped, snooze, workoutSuggestion, closing }

enum NotchLayout {
    static let expandedWidth: CGFloat = 460

    static func screen(for target: ReminderScreenTarget) -> NSScreen? {
        let screens = NSScreen.screens
        switch target {
        case .main:
            return NSScreen.main ?? screens.first
        case .active:
            return screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main ?? screens.first
        case .macBook:
            return screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? screens.first
        }
    }

    static func compactSize(on screen: NSScreen) -> CGSize {
        let width = screen.auxiliaryTopLeftArea.flatMap { left in
            screen.auxiliaryTopRightArea.map { $0.minX - left.maxX }
        } ?? 180
        let height = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 32
        return CGSize(width: width, height: height)
    }

    static func contentTopInset(on screen: NSScreen?) -> CGFloat {
        guard let screen, screen.safeAreaInsets.top > 0 else { return 24 }
        return screen.safeAreaInsets.top + 14
    }

    static func expandedHeight(on screen: NSScreen) -> CGFloat {
        contentTopInset(on: screen) + 148
    }
}

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
        panel.contentView?.wantsLayer = true
        screenChangeObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.repositionOnScreenChange() }
        }
    }

    private(set) var state: NotchPanelState = .hidden

    private func originY(on screen: NSScreen, height: CGFloat) -> CGFloat {
        // Use the physical frame, not visibleFrame. The latter starts below
        // the menu bar and makes a notch panel look detached from the display.
        screen.frame.maxY - height
    }

    func show(target: ReminderScreenTarget = .main) {
        self.target = target
        guard let screen = targetScreen(target) else { return }
        let compact = NotchLayout.compactSize(on: screen)
        state = .bumping
        let notch = screen.auxiliaryTopLeftArea.map { left in
            NSRect(x: left.maxX, y: screen.frame.maxY - 2, width: (screen.auxiliaryTopRightArea?.minX ?? left.maxX) - left.maxX, height: 2)
        }
        let anchor = notch?.midX ?? screen.frame.midX
        let x = min(max(anchor - compact.width / 2, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - compact.width - 8)
        let y = originY(on: screen, height: compact.height)
        panel.setFrame(NSRect(x: x, y: y, width: compact.width, height: compact.height), display: true)
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.orderFrontRegardless()
        state = .compact
        resizeWithArrivalBounce(on: screen, anchor: anchor) { [weak self] in self?.state = .expanded }
    }

    private func repositionOnScreenChange() {
        guard state != .hidden, let screen = targetScreen(target) else { return }
        let frame = panel.frame
        let anchor = screen.auxiliaryTopLeftArea.map { left in
            (left.maxX + (screen.auxiliaryTopRightArea?.minX ?? left.maxX)) / 2
        } ?? screen.frame.midX
        let x = min(max(anchor - frame.width / 2, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - frame.width - 8)
        let updated = NSRect(x: x, y: originY(on: screen, height: frame.height), width: frame.width, height: frame.height)
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

    private func resize(width: CGFloat, height: CGFloat, on screen: NSScreen, anchor: CGFloat, animated: Bool, duration: TimeInterval = 0.52, completion: (() -> Void)? = nil) {
        let x = min(max(anchor - width / 2, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - width - 8)
        let frame = NSRect(x: x, y: originY(on: screen, height: height), width: width, height: height)
        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = duration
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(frame, display: true)
            } completionHandler: { completion?() }
        } else { panel.setFrame(frame, display: true); completion?() }
    }

    private func resizeWithArrivalBounce(on screen: NSScreen, anchor: CGFloat, completion: (() -> Void)? = nil) {
        let width = NotchLayout.expandedWidth
        let height = NotchLayout.expandedHeight(on: screen)
        resize(width: width + 6, height: height + 3, on: screen, anchor: anchor, animated: true, duration: 0.42) { [weak self] in
            self?.resize(width: width, height: height, on: screen, anchor: anchor, animated: true, duration: 0.14, completion: completion)
        }
    }

    private func targetScreen(_ target: ReminderScreenTarget) -> NSScreen? { NotchLayout.screen(for: target) }

    func hide() {
        state = .closing
        guard let screen = panel.screen ?? NSScreen.main else { return }
        let compact = NotchLayout.compactSize(on: screen)
        let anchor = screen.auxiliaryTopLeftArea.map { left in
            (left.maxX + (screen.auxiliaryTopRightArea?.minX ?? left.maxX)) / 2
        } ?? screen.frame.midX
        resize(width: compact.width, height: compact.height, on: screen, anchor: anchor, animated: true) { [weak self] in
            guard let self else { return }
            if let screenChangeObserver {
                NotificationCenter.default.removeObserver(screenChangeObserver)
                self.screenChangeObserver = nil
            }
            panel.orderOut(nil); state = .hidden
        }
    }
}
