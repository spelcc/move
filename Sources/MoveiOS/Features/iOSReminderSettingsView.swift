import SwiftUI
import UserNotifications
import MoveCore
import MoveShared
import SwiftData

struct iOSReminderSettingsView: View {
    @Bindable var store: iOSAppStore
    @Query private var customExercises: [CustomExerciseEntity]

    var body: some View {
        NavigationStack {
            Form {
                Section("Rappels") {
                    Toggle("Activer les rappels", isOn: $store.reminder.enabled)
                    iOSSettingsStepper(
                        "Fréquence",
                        value: $store.reminder.intervalMinutes,
                        in: 15...180,
                        step: 15,
                        valueText: { "\($0) min" }
                    )
                    iOSSettingsStepper(
                        "Début",
                        value: $store.reminder.activeStartHour,
                        in: 0...max(0, store.reminder.activeEndHour - 1),
                        valueText: hour
                    )
                    iOSSettingsStepper(
                        "Fin",
                        value: $store.reminder.activeEndHour,
                        in: min(24, store.reminder.activeStartHour + 1)...24,
                        valueText: hour
                    )
                    iOSSettingsStepper(
                        "Snooze",
                        value: $store.reminder.snoozeMinutes,
                        in: 5...60,
                        step: 5,
                        valueText: { "\($0) min" }
                    )
                }

                Section("Grease the Groove") {
                    Toggle("Activer ce mode", isOn: $store.reminder.greaseTheGrooveEnabled)
                    if store.reminder.greaseTheGrooveEnabled {
                        Picker("Mouvement", selection: Binding(
                            get: { store.reminder.greaseTheGrooveExerciseID ?? allExercises.first?.id ?? "" },
                            set: { store.reminder.greaseTheGrooveExerciseID = $0 }
                        )) {
                            ForEach(allExercises, id: \.id) { exercise in
                                Text("\(exercise.emoji) \(exercise.name)").tag(exercise.id)
                            }
                        }
                        iOSSettingsStepper("Rep max", value: $store.reminder.greaseTheGrooveRepMax, in: 1...200)
                        iOSSettingsStepper("Pourcentage", value: $store.reminder.greaseTheGroovePercentage, in: 10...90, step: 5, valueText: { "\($0) %" })
                        iOSSettingsStepper("Réétalonnage", value: $store.reminder.greaseTheGrooveCalibrationIntervalDays, in: 7...90, step: 7, valueText: { "tous les \($0) jours" })
                        Text("Chaque rappel proposera uniquement ce mouvement, à \(max(1, store.reminder.greaseTheGrooveRepMax * store.reminder.greaseTheGroovePercentage / 100)) répétitions.")
                            .font(.footnote).foregroundStyle(.secondary)
                        if needsCalibration {
                            Label("Rep max à réétalonner", systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                        Button("Marquer la rep max comme étalonnée") {
                            store.reminder.greaseTheGrooveLastCalibratedAt = .now
                        }
                    }
                }

                Section("Jours actifs") {
                    ForEach(1...7, id: \.self) { weekday in
                        Toggle(Calendar.current.weekdaySymbols[weekday - 1], isOn: weekdayBinding(weekday))
                    }
                }

                Section("Appareil hôte") {
                    Picker("Programmer sur", selection: $store.reminderHost) {
                        Text("iPhone et Apple Watch").tag(ReminderHostPreference.phoneAndWatch)
                        Text("Mac").tag(ReminderHostPreference.mac)
                        Text("Tous les appareils").tag(ReminderHostPreference.all)
                    }
                    Text(hostExplanation).font(.footnote).foregroundStyle(.secondary)
                }

                Section("Catalogue") {
                    NavigationLink {
                        iOSMovementSettingsView(store: store)
                    } label: {
                        Label("Mouvements", systemImage: "list.bullet")
                    }
                }

                Section("État") {
                    notificationStatus
                    if let next = store.reminderState.nextReminderAt {
                        LabeledContent("Prochain rappel") {
                            Text(next, format: .dateTime.weekday().hour().minute())
                        }
                    }
                    if let error = store.schedulingError {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                    Button("Autoriser les notifications") {
                        Task { _ = await store.requestNotifications() }
                    }
                }
            }
            .navigationTitle("Réglages")
        }
        .onChange(of: store.reminder) { _, _ in store.persistSettings() }
        .onChange(of: store.reminderHost) { _, _ in store.persistSettings() }
    }

    private var notificationStatus: some View {
        let label: String
        let icon: String
        switch store.notificationStatus {
        case .authorized, .provisional, .ephemeral:
            label = "Notifications autorisées"
            icon = "checkmark.circle.fill"
        case .denied:
            label = "Notifications refusées dans iOS"
            icon = "exclamationmark.triangle.fill"
        case .notDetermined:
            label = "Autorisation non demandée"
            icon = "questionmark.circle"
        @unknown default:
            label = "État inconnu"
            icon = "questionmark.circle"
        }
        return Label(label, systemImage: icon)
    }

    private var hostExplanation: String {
        switch store.reminderHost {
        case .phoneAndWatch: "Cet iPhone programme les rappels. L’Apple Watch les relaie."
        case .mac: "Les rappels sont programmés uniquement par le Mac."
        case .all: "Mac et iPhone programment les rappels. Des doublons sont possibles."
        }
    }

    private var allExercises: [Exercise] {
        ExerciseLibrary.all + customExercises.filter { !$0.archived }.compactMap(\.exercise)
    }

    private var needsCalibration: Bool {
        guard let date = store.reminder.greaseTheGrooveLastCalibratedAt,
              let due = Calendar.current.date(byAdding: .day, value: store.reminder.greaseTheGrooveCalibrationIntervalDays, to: date)
        else { return true }
        return due <= .now
    }

    private func hour(_ value: Int) -> String { String(format: "%02d:00", value) }

    private func weekdayBinding(_ weekday: Int) -> Binding<Bool> {
        .init(
            get: { store.reminder.enabledWeekdays.contains(weekday) },
            set: { enabled in
                if enabled { store.reminder.enabledWeekdays.insert(weekday) }
                else { store.reminder.enabledWeekdays.remove(weekday) }
            }
        )
    }
}
