import SwiftUI
import MoveCore

struct NotchPromptView: View {
    @Bindable var store: MoveStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onClose: () -> Void
    let onResize: (CGFloat, CGFloat) -> Void
    @State private var bumped = false
    @State private var reaction: Reaction?

    init(store: MoveStore, onClose: @escaping () -> Void = {}, onResize: @escaping (CGFloat, CGFloat) -> Void = { _, _ in }) {
        self.store = store
        self.onClose = onClose
        self.onResize = onResize
    }

    private enum Reaction {
        case success, skipped, snoozed

        var title: String {
            switch self {
            case .success: MoveCopy.text("notch.reaction.success")
            case .skipped: MoveCopy.text("notch.reaction.skipped")
            case .snoozed: MoveCopy.text("notch.reaction.snoozed")
            }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            if store.noCompatibleExercises {
                Text(MoveCopy.text("notch.noCompatible.title"))
                    .font(.headline).foregroundStyle(.white).multilineTextAlignment(.center)
                Text(MoveCopy.text("notch.noCompatible.message"))
                    .font(.caption).foregroundStyle(.white.opacity(0.65))
                Button(MoveCopy.text("notch.noCompatible.reset")) { store.enableAllExercises() }
                    .buttonStyle(.borderedProminent).tint(.white).foregroundStyle(.black)
            } else if let reaction {
                Text(reaction.title).font(.headline).foregroundStyle(.white).multilineTextAlignment(.center)
                Text(MoveCopy.text("notch.reaction.untilNext")).font(.caption).foregroundStyle(.white.opacity(0.65))
            } else {
                HStack(spacing: 10) {
                    if store.appearance.emojisEnabled {
                        Text(store.currentExercise.emoji).font(.system(size: 28)).accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(prompt).font(.headline).foregroundStyle(.white).accessibilityAddTraits(.isHeader)
                        Text(subMessage).font(.caption).foregroundStyle(.white.opacity(0.65))
                    }
                    Spacer()
                }
                HStack(spacing: 8) {
                    Button(MoveCopy.text("notch.action.done")) { complete() }.buttonStyle(.borderedProminent).tint(.white).foregroundStyle(.black)
                    Button(MoveCopy.text("notch.action.skip")) { skip() }.buttonStyle(.bordered).tint(.white)
                }
                HStack(spacing: 18) {
                    Menu(MoveCopy.text("notch.action.snooze")) {
                        Button("15 minutes") { snooze(for: 15) }
                        Button("30 minutes") { snooze(for: 30) }
                    }
                    .menuStyle(.borderlessButton)
                    .foregroundStyle(.white.opacity(0.75))
                    Button(MoveCopy.text("notch.action.change")) { store.chooseNext(); onResize(460, 300) }.keyboardShortcut("c", modifiers: [.command]).buttonStyle(.plain).foregroundStyle(.white.opacity(0.75))
                }
            }
        }
        // Leave the notch depth clear: text starts below the physical cutout,
        // while the sticky shell remains attached to the top edge.
        // Keep every text baseline below the physical notch, including when
        // the panel is hosted on a display whose safe-area metadata is absent.
        .padding(.top, 92)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(.black, in: StickyPanelShape(radius: 30))
        .frame(maxWidth: 460)
        .scaleEffect(bumped ? 1 : 0.92, anchor: .top)
        .offset(y: bumped ? 0 : -18)
        .opacity(bumped ? 1 : 0)
        .onAppear {
            if reduceMotion || store.appearance.animations == .disabled { bumped = true }
            else {
                let response = store.appearance.animations == .reduced ? 0.28 : 0.42
                withAnimation(.spring(response: response, dampingFraction: 0.68)) { bumped = true }
            }
        }
    }

    private func complete() { store.completeCurrent(); show(.success) }
    private func skip() { store.skipCurrent(); show(.skipped) }
    private func snooze(for minutes: Int) { store.snoozeCurrent(for: minutes); show(.snoozed) }

    private func show(_ value: Reaction) {
        reaction = value
        Task {
            try? await Task.sleep(for: .seconds(2))
            onClose()
        }
    }
    private var prompt: String {
        switch store.currentExercise.metric {
        case .repetitions: "Fais \(store.currentExercise.defaultAmount) \(store.currentExercise.name.lowercased())"
        case .seconds: "\(store.currentExercise.name) pendant \(store.currentExercise.defaultAmount) s"
        case .minutes: "\(store.currentExercise.name) pendant \(store.currentExercise.defaultAmount) min"
        case .free: store.currentExercise.name
        }
    }

    private var subMessage: String {
        switch store.appearance.humor {
        case .normal: MoveCopy.text("notch.humor.normal")
        case .discreet: MoveCopy.text("notch.humor.discreet")
        case .disabled: MoveCopy.text("notch.humor.disabled")
        }
    }
}

private struct StickyPanelShape: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(radius, min(rect.width / 3, rect.height / 2))
        var path = Path()
        // Broad, soft shoulders make the top edge feel attached to the notch,
        // like a Dynamic Island expansion rather than a rounded rectangle.
        let shoulder = min(r * 1.55, rect.width / 3.2)
        path.move(to: CGPoint(x: rect.minX + shoulder, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - shoulder, y: rect.minY))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + shoulder),
                      control1: CGPoint(x: rect.maxX - shoulder * 0.18, y: rect.minY),
                      control2: CGPoint(x: rect.maxX, y: rect.minY + shoulder * 0.18))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                      control1: CGPoint(x: rect.maxX, y: rect.maxY - r * 0.28),
                      control2: CGPoint(x: rect.maxX - r * 0.28, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                      control1: CGPoint(x: rect.minX + r * 0.28, y: rect.maxY),
                      control2: CGPoint(x: rect.minX, y: rect.maxY - r * 0.28))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + shoulder))
        path.addCurve(to: CGPoint(x: rect.minX + shoulder, y: rect.minY),
                      control1: CGPoint(x: rect.minX, y: rect.minY + shoulder * 0.18),
                      control2: CGPoint(x: rect.minX + shoulder * 0.18, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
