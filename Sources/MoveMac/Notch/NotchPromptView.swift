import SwiftUI
import MoveCore

struct NotchPromptView: View {
    @Bindable var store: MoveStore
    @State private var bumped = false
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text(store.currentExercise.emoji).font(.system(size: 28)).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(prompt).font(.headline).foregroundStyle(.white).accessibilityAddTraits(.isHeader)
                    Text("Ton squelette a encore déposé une réclamation.").font(.caption).foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
            }
            HStack {
                Button("C’est fait") { store.completeCurrent() }.buttonStyle(.borderedProminent).tint(.white).foregroundStyle(.black)
                Button("La flemme") { store.skipCurrent() }.buttonStyle(.bordered).tint(.white)
                Button("Reporter") { store.snoozeCurrent(for: store.reminder.snoozeMinutes) }.buttonStyle(.plain).foregroundStyle(.white.opacity(0.75))
                Button("Changer") { store.chooseNext() }.keyboardShortcut("c", modifiers: [.command]).buttonStyle(.plain).foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(16)
        .background(.black, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .scaleEffect(bumped ? 1 : 0.92, anchor: .top)
        .offset(y: bumped ? 0 : -18)
        .opacity(bumped ? 1 : 0)
        .onAppear { withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) { bumped = true } }
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
