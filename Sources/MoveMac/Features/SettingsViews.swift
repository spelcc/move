import SwiftUI
import MoveCore

struct MovementSettingsView: View {
    @Bindable var store: MoveStore
    var body: some View {
        List(ExerciseLibrary.builtIn) { exercise in
            Toggle(isOn: Binding(get: { !store.movement.disabledExerciseIDs.contains(exercise.id) }, set: { enabled in if enabled { store.movement.disabledExerciseIDs.remove(exercise.id) } else { store.movement.disabledExerciseIDs.insert(exercise.id) } })) {
                HStack { Text(exercise.emoji); VStack(alignment: .leading) { Text(exercise.name); Text(exercise.category.rawValue).font(.caption).foregroundStyle(.secondary) } }
            }
        }.navigationTitle("Mouvements")
    }
}

struct SettingsView: View {
    @Bindable var store: MoveStore
    var body: some View {
        Form {
            Section("Rappels") { Stepper("Toutes les \(store.reminder.intervalMinutes) minutes", value: $store.reminder.intervalMinutes, in: 15...180, step: 15); Stepper("Début à \(store.reminder.activeStartHour) h", value: $store.reminder.activeStartHour, in: 0...23); Stepper("Fin à \(store.reminder.activeEndHour) h", value: $store.reminder.activeEndHour, in: 1...24) }
            Section("Contraintes") { Toggle("Sans sauts", isOn: tagBinding("jump")); Toggle("Silencieux", isOn: tagBinding("noisy")); Toggle("Éviter le sol", isOn: tagBinding("floor")); Toggle("Éviter les poignets", isOn: tagBinding("wrists")); Toggle("Barre de traction disponible", isOn: equipmentBinding("pullup-bar")) }
        }.formStyle(.grouped).padding().navigationTitle("Réglages")
    }
    private func tagBinding(_ tag: String) -> Binding<Bool> {
        .init(get: { store.movement.excludedTags.contains(tag) }, set: { enabled in
            if enabled { store.movement.excludedTags.insert(tag) } else { store.movement.excludedTags.remove(tag) }
        })
    }
    private func equipmentBinding(_ item: String) -> Binding<Bool> {
        .init(get: { store.movement.availableEquipment.contains(item) }, set: { enabled in
            if enabled { store.movement.availableEquipment.insert(item) } else { store.movement.availableEquipment.remove(item) }
        })
    }
}
