import SwiftUI
import MoveCore

struct iOSReminderSettingsView: View {
    @AppStorage("move.reminders.enabled") private var enabled = true
    @AppStorage("move.reminders.host") private var hostRaw = ReminderHostPreference.phoneAndWatch.rawValue
    @AppStorage("move.reminders.intervalMinutes") private var intervalMinutes = 60
    @AppStorage("move.reminders.startHour") private var startHour = 9
    @AppStorage("move.reminders.endHour") private var endHour = 19
    @AppStorage("move.reminders.snoozeMinutes") private var snoozeMinutes = 15
    var body: some View {
        Form {
            Section("Rappels") {
                Toggle("Activer les rappels", isOn: $enabled)
                Stepper("Fréquence : \(intervalMinutes) min", value: $intervalMinutes, in: 15...180, step: 15)
                Stepper("Début : \(String(format: "%02d:00", startHour))", value: $startHour, in: 0...23)
                Stepper("Fin : \(String(format: "%02d:00", endHour))", value: $endHour, in: 1...24)
                Stepper("Snooze : \(snoozeMinutes) min", value: $snoozeMinutes, in: 5...60, step: 5)
            Picker("Appareil hôte", selection: $hostRaw) {
                Text("iPhone et Apple Watch").tag(ReminderHostPreference.phoneAndWatch.rawValue)
                Text("Mac").tag(ReminderHostPreference.mac.rawValue)
                Text("Tous les appareils").tag(ReminderHostPreference.all.rawValue)
            }
            Text("L’Apple Watch reçoit les rappels de l’iPhone.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("À propos") { Text("Les réglages sont enregistrés automatiquement sur cet iPhone.").font(.footnote).foregroundStyle(.secondary) }
        }
            .navigationTitle("Réglages")
    }
}
