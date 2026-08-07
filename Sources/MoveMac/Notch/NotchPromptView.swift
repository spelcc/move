import SwiftUI
import MoveCore

struct NotchPromptView: View {
    @Bindable var store: MoveStore
    let onClose: () -> Void

    init(store: MoveStore, onClose: @escaping () -> Void = {}) {
        self.store = store
        self.onClose = onClose
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                NotchShellShape(topCornerRadius: 30, bottomCornerRadius: 30)
                    .fill(.black)

                promptContent
                    .padding(.top, NotchLayout.contentTopInset(on: NotchLayout.screen(for: store.appearance.screenTarget)))
                    .padding(.horizontal, 44)
                    .padding(.bottom, 16)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
            .contentShape(NotchShellShape(topCornerRadius: 30, bottomCornerRadius: 30))
        }
    }

    @ViewBuilder private var promptContent: some View {
        VStack(spacing: 12) {
            if store.noCompatibleExercises {
                Text(MoveCopy.text("notch.noCompatible.title"))
                    .font(.headline).foregroundStyle(.white).multilineTextAlignment(.center)
                Text(MoveCopy.text("notch.noCompatible.message"))
                    .font(.caption).foregroundStyle(.white.opacity(0.65))
                Button(MoveCopy.text("notch.noCompatible.reset")) { store.enableAllExercises() }
                    .buttonStyle(.borderedProminent).tint(.white).foregroundStyle(.black)
            } else {
                VStack(spacing: 6) {
                    if store.appearance.emojisEnabled {
                        Text(store.currentExercise.emoji).font(.system(size: 28)).accessibilityHidden(true)
                    }
                    Text(prompt).font(.headline).foregroundStyle(.white).multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
                    Text(subMessage).font(.caption).foregroundStyle(.white.opacity(0.65)).multilineTextAlignment(.center)
                }
                HStack(spacing: 8) {
                    NotchActionButton(title: MoveCopy.text("notch.action.snooze"), color: .red.opacity(0.18), textColor: .red) {
                        snooze(for: store.reminder.snoozeMinutes)
                    }
                    NotchActionButton(title: MoveCopy.text("notch.action.done"), color: .green.opacity(0.18), textColor: .green) {
                        complete()
                    }
                    NotchActionButton(title: MoveCopy.text("notch.action.other"), color: Color.white.opacity(0.16), textColor: .white.opacity(0.82)) {
                        store.chooseNext()
                    }
                    .keyboardShortcut("c", modifiers: [.command])
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(MoveCopy.text("notch.actions"))
            }
        }
    }

    private func complete() {
        store.completeCurrent()
        onClose()
    }
    private func snooze(for minutes: Int) {
        store.snoozeCurrent(for: minutes)
        onClose()
    }

    private var prompt: String {
        switch store.currentExercise.metric {
        case .repetitions: "\(store.currentExercise.defaultAmount) \(store.currentExercise.displayName.lowercased())"
        case .seconds: "\(store.currentExercise.displayName) — \(store.currentExercise.defaultAmount) s"
        case .minutes: "\(store.currentExercise.displayName) — \(store.currentExercise.defaultAmount) min"
        case .free: store.currentExercise.displayName
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

private struct NotchActionButton: View {
    let title: String
    let color: Color
    let textColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(color, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}
