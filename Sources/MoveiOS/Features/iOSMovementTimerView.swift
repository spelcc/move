import SwiftUI

struct iOSMovementTimerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var machine: iOSMovementTimerMachine

    private let onFinish: () -> Void

    init(durationSeconds: Int, onFinish: @escaping () -> Void) {
        _machine = State(initialValue: iOSMovementTimerMachine(durationSeconds: durationSeconds))
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 14) {
            switch machine.phase {
            case .idle:
                Button {
                    machine.start()
                } label: {
                    Label("Lancer le chrono", systemImage: "timer")
                }
                .buttonStyle(.borderedProminent)

            case .running:
                countdown
                HStack {
                    Button("Pause", systemImage: "pause.fill") {
                        machine.pause()
                    }
                    Button("Annuler", role: .cancel) {
                        machine.cancel()
                    }
                }
                .buttonStyle(.bordered)

            case .paused:
                countdown
                Text("En pause")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Reprendre", systemImage: "play.fill") {
                        machine.resume()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Annuler", role: .cancel) {
                        machine.cancel()
                    }
                    .buttonStyle(.bordered)
                }

            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)
                Text("Temps écoulé")
                    .font(.headline)
                HStack {
                    Button("Terminer") {
                        finish()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(machine.completionWasConsumed)
                    Button("Annuler", role: .cancel) {
                        machine.cancel()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
        .task(id: machine.phase) {
            guard machine.phase == .running else { return }
            while !Task.isCancelled, machine.phase == .running {
                do {
                    try await Task.sleep(for: .milliseconds(200))
                } catch {
                    return
                }
                machine.tick()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                machine.tick()
            }
        }
    }

    private var countdown: some View {
        VStack(spacing: 8) {
            Text(formattedTime)
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityLabel("\(machine.remainingSeconds) secondes restantes")
            ProgressView(value: machine.progress)
                .tint(.accentColor)
        }
    }

    private var formattedTime: String {
        let minutes = machine.remainingSeconds / 60
        let seconds = machine.remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func finish() {
        guard machine.consumeCompletion() else { return }
        onFinish()
        machine.cancel()
    }
}
