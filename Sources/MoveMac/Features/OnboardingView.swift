import SwiftUI
import UserNotifications
import MoveCore

struct OnboardingView: View {
    @Bindable var store: MoveStore
    @AppStorage("move.onboardingCompleted") private var completed = false
    @State private var step = 0
    @State private var interval = 60
    @State private var notificationsEnabled = false
    @State private var notificationError: String?
    @State private var launchAtLogin = false
    @State private var launchError: String?
    let onTestNotch: () -> Void

    init(store: MoveStore, onTestNotch: @escaping () -> Void = {}) { self.store = store; self.onTestNotch = onTestNotch }

    private let pages = [
        ("Bouge un peu, souvent.", "Move te rappelle de bouger.\nPas de compte. Pas de classement. Pas de coach qui crie."),
        ("Choisis ton rythme.", "Un rappel toutes les 15 à 180 minutes, dans la plage horaire qui te convient."),
        ("Adapte tes mouvements.", "Indique le matériel disponible pour recevoir des défis compatibles."),
        ("Règle l’ambiance.", "Choisis les emojis et les animations qui te ressemblent."),
        ("Teste l’encoche.", "Une petite capsule noire apparaît au bon moment, sans interrompre ton travail.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Move").font(.system(size: 38, weight: .black, design: .rounded))
            Text(pages[step].0).font(.title.bold())
            Text(pages[step].1).font(.body).foregroundStyle(.secondary)
            if step == 1 {
                Stepper(String(format: MoveCopy.text("onboarding.interval"), interval), value: $interval, in: 15...180, step: 15)
                Stepper(String(format: MoveCopy.text("onboarding.startHour"), store.reminder.activeStartHour), value: $store.reminder.activeStartHour, in: 0...23)
                Stepper(String(format: MoveCopy.text("onboarding.endHour"), store.reminder.activeEndHour), value: $store.reminder.activeEndHour, in: 1...24)
            } else if step == 2 {
                Toggle(MoveCopy.text("equipment.chair"), isOn: equipmentBinding("chair"))
                Toggle(MoveCopy.text("equipment.pullupBar"), isOn: equipmentBinding("pullup-bar"))
                Toggle(MoveCopy.text("equipment.dumbbells"), isOn: equipmentBinding("dumbbells"))
                Toggle(MoveCopy.text("equipment.band"), isOn: equipmentBinding("band"))
            } else if step == 3 {
                Toggle(MoveCopy.text("settings.emojis"), isOn: $store.appearance.emojisEnabled)
                Picker(MoveCopy.text("settings.animations"), selection: $store.appearance.animations) {
                    Text(MoveCopy.text("settings.full")).tag(AnimationMode.full)
                    Text(MoveCopy.text("settings.reduced")).tag(AnimationMode.reduced)
                    Text(MoveCopy.text("settings.disabled")).tag(AnimationMode.disabled)
                }
            } else if step == 4 {
                Toggle(MoveCopy.text("settings.launchAtLogin"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let launchError { Text(launchError).font(.caption).foregroundStyle(.red) }
                if let notificationError { Text(notificationError).font(.caption).foregroundStyle(.red) }
            }
            Spacer()
            HStack {
                if step > 0 { Button(MoveCopy.text("onboarding.back")) { step -= 1 } }
                Spacer()
                Button(step == pages.count - 1 ? MoveCopy.text("onboarding.testNotch") : MoveCopy.text("onboarding.continue")) {
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

    private func equipmentBinding(_ equipment: String) -> Binding<Bool> {
        Binding(
            get: { store.movement.availableEquipment.contains(equipment) },
            set: { enabled in
                if enabled { store.movement.availableEquipment.insert(equipment) }
                else { store.movement.availableEquipment.remove(equipment) }
            }
        )
    }

    private func finish() {
        store.reminder.intervalMinutes = interval
        store.persistSettings()
        Task {
            notificationsEnabled = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
            if !notificationsEnabled {
                notificationError = "Les notifications sont désactivées. Tu peux les autoriser dans Réglages Système pour recevoir les rappels."
            }
            onTestNotch()
            completed = true
            NotificationCenter.default.post(name: .moveOnboardingCompleted, object: nil)
        }
    }
}
