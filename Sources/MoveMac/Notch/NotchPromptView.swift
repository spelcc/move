import SwiftUI
import MoveCore

struct NotchPromptView: View {
    @Bindable var store: MoveStore
    let onClose: () -> Void
    @State private var bumped = false
    @State private var reaction: Reaction?

    init(store: MoveStore, onClose: @escaping () -> Void = {}) {
        self.store = store
        self.onClose = onClose
    }

    private enum Reaction {
        case success, skipped, snoozed

        var title: String {
            switch self {
            case .success: "Bien joué. La chaise perd du terrain."
            case .skipped: "La flemme gagne cette manche."
            case .snoozed: "D’accord, on remet ça bientôt."
            }
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            if let reaction {
                Text(reaction.title).font(.headline).foregroundStyle(.white).multilineTextAlignment(.center)
                Text("À bientôt.").font(.caption).foregroundStyle(.white.opacity(0.65))
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
                    Button("C’est fait") { complete() }.buttonStyle(.borderedProminent).tint(.white).foregroundStyle(.black)
                    Button("La flemme") { skip() }.buttonStyle(.bordered).tint(.white)
                }
                HStack(spacing: 18) {
                    Button("Reporter") { snooze() }.buttonStyle(.plain).foregroundStyle(.white.opacity(0.75))
                    Button("Changer") { store.chooseNext() }.keyboardShortcut("c", modifiers: [.command]).buttonStyle(.plain).foregroundStyle(.white.opacity(0.75))
                }
            }
        }
        // Leave the notch depth clear: text starts below the physical cutout,
        // while the sticky shell remains attached to the top edge.
        .padding(.top, 30)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .background(.black, in: StickyPanelShape(radius: 30))
        .frame(maxWidth: 460)
        .scaleEffect(bumped ? 1 : 0.92, anchor: .top)
        .offset(y: bumped ? 0 : -18)
        .opacity(bumped ? 1 : 0)
        .onAppear {
            if store.appearance.animations == .disabled { bumped = true }
            else {
                let response = store.appearance.animations == .reduced ? 0.28 : 0.42
                withAnimation(.spring(response: response, dampingFraction: 0.68)) { bumped = true }
            }
        }
    }

    private func complete() { store.completeCurrent(); show(.success) }
    private func skip() { store.skipCurrent(); show(.skipped) }
    private func snooze() { store.snoozeCurrent(for: store.reminder.snoozeMinutes); show(.snoozed) }

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
        case .normal: "Ton squelette a encore déposé une réclamation."
        case .discreet: "Une petite pause mouvement ?"
        case .disabled: "Rappel de mouvement."
        }
    }
}

private struct StickyPanelShape: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(radius, min(rect.width / 3, rect.height / 2))
        var path = Path()
        path.move(to: CGPoint(x: r, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        // Concave top corners make the capsule feel attached to the screen edge.
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX - r, y: rect.minY + r))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX - r, y: rect.maxY - r))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX + r, y: rect.maxY - r))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(to: CGPoint(x: r, y: rect.minY), control: CGPoint(x: r, y: rect.minY + r))
        path.closeSubpath()
        return path
    }
}
