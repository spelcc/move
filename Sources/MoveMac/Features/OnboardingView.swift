import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @AppStorage("move.onboardingCompleted") private var completed = false
    @State private var step = 0
    @State private var interval = 60
    @State private var notificationsEnabled = false
    let onTestNotch: () -> Void

    init(onTestNotch: @escaping () -> Void = {}) { self.onTestNotch = onTestNotch }

    private let pages = [
        ("Bouge un peu, souvent.", "Move te rappelle de bouger.\nPas de compte. Pas de classement. Pas de coach qui crie."),
        ("Choisis ton rythme.", "Un rappel toutes les 15 à 180 minutes, dans la plage horaire qui te convient."),
        ("Teste l’encoche.", "Une petite capsule noire apparaît au bon moment, sans interrompre ton travail.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Move").font(.system(size: 38, weight: .black, design: .rounded))
            Text(pages[step].0).font(.title.bold())
            Text(pages[step].1).font(.body).foregroundStyle(.secondary)
            if step == 1 {
                Stepper("Toutes les \(interval) minutes", value: $interval, in: 15...180, step: 15)
            }
            Spacer()
            HStack {
                if step > 0 { Button("Retour") { step -= 1 } }
                Spacer()
                Button(step == pages.count - 1 ? "Tester l’encoche" : "Continuer") {
                    if step < pages.count - 1 { step += 1 } else { finish() }
                }.buttonStyle(.borderedProminent)
            }
        }.padding(36).frame(width: 460, height: 340)
    }

    private func finish() {
        Task {
            notificationsEnabled = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
            onTestNotch()
            completed = true
        }
    }
}
