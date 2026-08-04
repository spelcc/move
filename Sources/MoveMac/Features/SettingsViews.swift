import SwiftUI
import SwiftData
import MoveCore

struct MovementSettingsView: View {
    @Bindable var store: MoveStore
    @Environment(\.modelContext) private var modelContext
    @Query private var customExercises: [CustomExerciseEntity]
    @State private var search = ""
    @State private var showingNewExercise = false
    var body: some View {
        List {
            Section("Intégrés") {
                ForEach(ExerciseLibrary.all.filter { search.isEmpty || $0.name.localizedStandardContains(search) }) { exercise in
            Toggle(isOn: Binding(get: { !store.movement.disabledExerciseIDs.contains(exercise.id) }, set: { enabled in if enabled { store.movement.disabledExerciseIDs.remove(exercise.id) } else { store.movement.disabledExerciseIDs.insert(exercise.id) } })) {
                HStack { Text(exercise.emoji); VStack(alignment: .leading) { Text(exercise.name); Text(exercise.category.rawValue).font(.caption).foregroundStyle(.secondary) } }
            }
                }
            }
            Section("Personnalisés") {
                ForEach(customExercises.filter { !$0.archived && (search.isEmpty || $0.name.localizedStandardContains(search)) }) { exercise in
                    HStack { Text(exercise.emoji); Text(exercise.name); Spacer(); Text("\(exercise.defaultAmount)").foregroundStyle(.secondary) }
                }.onDelete { offsets in
                    for index in offsets { customExercises[index].archived = true; customExercises[index].updatedAt = .now }
                }
            }
        }.toolbar { Button("Nouveau mouvement", systemImage: "plus") { showingNewExercise = true } }
        .sheet(isPresented: $showingNewExercise) { NewExerciseView { name, emoji, amount in
            modelContext.insert(CustomExerciseEntity(name: name, emoji: emoji, defaultAmount: amount))
            try? modelContext.save()
        } }
        .searchable(text: $search, prompt: "Rechercher un mouvement").navigationTitle("Mouvements")
    }
}

private struct NewExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = "💪"
    @State private var amount = 10
    let onSave: (String, String, Int) -> Void
    var body: some View {
        Form {
            TextField("Nom", text: $name)
            TextField("Emoji", text: $emoji)
            Stepper("Quantité par défaut : \(amount)", value: $amount, in: 1...999)
            HStack { Spacer(); Button("Annuler") { dismiss() }; Button("Créer") { onSave(name, emoji, amount); dismiss() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty).buttonStyle(.borderedProminent) }
        }.padding().frame(width: 360)
    }
}

struct SettingsView: View {
    @Bindable var store: MoveStore
    var body: some View {
        Form {
            Section("Rappels") { Stepper("Toutes les \(store.reminder.intervalMinutes) minutes", value: $store.reminder.intervalMinutes, in: 15...180, step: 15); Stepper("Début à \(store.reminder.activeStartHour) h", value: $store.reminder.activeStartHour, in: 0...23); Stepper("Fin à \(store.reminder.activeEndHour) h", value: $store.reminder.activeEndHour, in: 1...24) }
            Section("Contraintes") { Toggle("Sans sauts", isOn: tagBinding("jump")); Toggle("Silencieux", isOn: tagBinding("noisy")); Toggle("Éviter le sol", isOn: tagBinding("floor")); Toggle("Éviter les poignets", isOn: tagBinding("wrists")); Toggle("Barre de traction disponible", isOn: equipmentBinding("pullup-bar")) }
        }.formStyle(.grouped).padding().navigationTitle("Réglages")
        .onChange(of: store.reminder) { _, _ in store.persistSettings() }
        .onChange(of: store.movement) { _, _ in store.persistSettings(); store.chooseNext() }
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
