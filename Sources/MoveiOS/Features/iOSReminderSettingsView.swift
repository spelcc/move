import SwiftUI
import MoveCore

struct iOSReminderSettingsView: View {
    @AppStorage("move.reminders.enabled") private var enabled = true
    @AppStorage("move.reminders.host") private var hostRaw = ReminderHostPreference.phoneAndWatch.rawValue
    var body: some View {
        Form { Section("Rappels") { Toggle("Activer les rappels", isOn: $enabled)
            Picker("Appareil hôte", selection: $hostRaw) {
                Text("iPhone et Apple Watch").tag(ReminderHostPreference.phoneAndWatch.rawValue)
                Text("Mac").tag(ReminderHostPreference.mac.rawValue)
                Text("Tous les appareils").tag(ReminderHostPreference.all.rawValue)
            }
            Text("L’Apple Watch reçoit la file de l’iPhone et ne programme pas de file locale.").font(.footnote).foregroundStyle(.secondary) } }
            .navigationTitle("Réglages")
    }
}
