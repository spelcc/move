import SwiftUI
import UserNotifications
import MoveCore

struct OnboardingView: View {
    @Bindable var store: MoveStore
    @AppStorage("move.onboardingCompleted") private var completed = false
    @State private var step = 0
    @State private var interval = 60
    @State private var notificationsEnabled = false
    @State private var launchAtLogin = false
    @State private var launchError: String?
    let onTestNotch: () -> Void

    init(store: MoveStore, onTestNotch: @escaping () -> Void = {}) { self.store = store; self.onTestNotch = onTestNotch }

    private let pages = [
        ("Bouge un peu, souvent.", "Move te rappelle de bouger.\nPas de compte. Pas de classement. Pas de coach qui crie."),
        ("Choisis ton rythme.", "Un rappel toutes les 15 à 180 minutes, dans la plage horaire qui te convient."),
        ("Règle l’ambiance.", "Choisis les mouvements, les emojis et les animations qui te ressemblent."),
        ("Teste l’encoche.", "Une petite capsule noire apparaît au bon moment, sans interrompre ton travail.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Move").font(.system(size: 38, weight: .black, design: .rounded))
            Text(pages[step].0).font(.title.bold())
            Text(pages[step].1).font(.body).foregroundStyle(.secondary)
            if step == 1 {
                Stepper("Toutes les \(interval) minutes", value: $interval, in: 15...180, step: 15)
                Stepper("Début : \(store.reminder.activeStartHour) h", value: $store.reminder.activeStartHour, in: 0...23)
                Stepper("Fin : \(store.reminder.activeEndHour) h", value: $store.reminder.activeEndHour, in: 1...24)
            } else if step == 2 {
                Toggle("Afficher les emojis", isOn: $store.appearance.emojisEnabled)
                Picker("Animations", selection: $store.appearance.animations) {
                    Text("Complètes").tag(AnimationMode.full)
                    Text("Réduites").tag(AnimationMode.reduced)
                    Text("Désactivées").tag(AnimationMode.disabled)
                }
            } else if step == 3 {
                Toggle("Lancer Move à la connexion", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let launchError { Text(launchError).font(.caption).foregroundStyle(.red) }
            }
            Spacer()
            HStack {
                if step > 0 { Button("Retour") { step -= 1 } }
                Spacer()
                Button(step == pages.count - 1 ? "Tester l’encoche" : "Continuer") {
                    if step < pages.count - 1 { step += 1 } else { finish() }
                }.buttonStyle(.borderedProminent)
            }
        }
        .onAppear { launchAtLogin = LaunchAtLoginService.isEnabled }
        .padding(36).frame(width: 460, height: 380)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do { try LaunchAtLoginService.setEnabled(enabled); launchAtLogin = enabled }
        catch { launchError = "Lancement automatique indisponible pour le moment." }
    }

    private func finish() {
        store.reminder.intervalMinutes = interval
        store.persistSettings()
        Task {
            notificationsEnabled = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
            onTestNotch()
            completed = true
        }
    }
}
