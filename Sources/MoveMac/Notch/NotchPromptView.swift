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
                    Text(store.currentExercise.emoji).font(.system(size: 28)).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(prompt).font(.headline).foregroundStyle(.white).accessibilityAddTraits(.isHeader)
                        Text("Ton squelette a encore déposé une réclamation.").font(.caption).foregroundStyle(.white.opacity(0.65))
                    }
                    Spacer()
                }
                HStack {
                    Button("C’est fait") { complete() }.buttonStyle(.borderedProminent).tint(.white).foregroundStyle(.black)
                    Button("La flemme") { skip() }.buttonStyle(.bordered).tint(.white)
                    Button("Reporter") { snooze() }.buttonStyle(.plain).foregroundStyle(.white.opacity(0.75))
                    Button("Changer") { store.chooseNext() }.keyboardShortcut("c", modifiers: [.command]).buttonStyle(.plain).foregroundStyle(.white.opacity(0.75))
                }
            }
        }
        .padding(16)
        .background(.black, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .scaleEffect(bumped ? 1 : 0.92, anchor: .top)
        .offset(y: bumped ? 0 : -18)
        .opacity(bumped ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) { bumped = true } }
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
}
