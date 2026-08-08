import SwiftUI
import MoveCore

struct WorkoutTimerView: View {
    @State private var remaining = 0
    @State private var running = false
    @State private var timer: Timer?
    var body: some View {
        NavigationStack { VStack(spacing: 24) {
            Text("Timer libre").font(.title.bold())
            Text(time).font(.system(size: 64, weight: .bold, design: .rounded)).monospacedDigit()
            HStack { Button("− 30 s") { remaining = max(0, remaining - 30) }; Button("+ 30 s") { remaining += 30 } }
            Button(running ? "Pause" : "Démarrer") { toggle() }.buttonStyle(.borderedProminent).disabled(remaining == 0 && !running)
            Button("Réinitialiser") { stop(); remaining = 60 }.buttonStyle(.bordered)
        }.padding().navigationTitle("Timer") .onAppear { if remaining == 0 { remaining = 60 } }.onDisappear { stop() } }
    }
    private var time: String { String(format: "%02d:%02d", remaining / 60, remaining % 60) }
    private func toggle() { running ? stop() : start() }
    private func start() { running = true; timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in if remaining > 0 { remaining -= 1 } else { stop() } } }
    private func stop() { timer?.invalidate(); timer = nil; running = false }
}
