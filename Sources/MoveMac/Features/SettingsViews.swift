import SwiftUI
import SwiftData
import MoveCore

struct MovementSettingsView: View {
    @Bindable var store: MoveStore
    @Environment(\.modelContext) private var modelContext
    @Query private var customExercises: [CustomExerciseEntity]
    @State private var search = ""
    @State private var showingNewExercise = false
    @State private var editingExercise: CustomExerciseEntity?
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
                ForEach(visibleCustomExercises) { exercise in
                    Toggle(isOn: customEnabledBinding(exercise)) {
                        HStack { Text(exercise.emoji); VStack(alignment: .leading) { Text(exercise.name); Text("\(exercise.categoryRaw) • \(exercise.metricRaw)").font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("\(exercise.defaultAmount)").foregroundStyle(.secondary) }
                    }
                    .contextMenu {
                        Button("Modifier") { editingExercise = exercise }
                        Button("Dupliquer") { duplicate(exercise) }
                        Button("Archiver", role: .destructive) { archive(exercise) }
                    }
                }.onDelete { offsets in
                    for index in offsets { archive(visibleCustomExercises[index]) }
                }
            }
        }.toolbar { Button("Nouveau mouvement", systemImage: "plus") { showingNewExercise = true } }
        .sheet(isPresented: $showingNewExercise) { NewExerciseView { exercise in
            modelContext.insert(exercise)
            try? modelContext.save()
        } }
        .sheet(item: $editingExercise) { exercise in EditExerciseView(exercise: exercise) }
        .searchable(text: $search, prompt: "Rechercher un mouvement").navigationTitle("Mouvements")
    }

    private var visibleCustomExercises: [CustomExerciseEntity] { customExercises.filter { !$0.archived && (search.isEmpty || $0.name.localizedStandardContains(search)) } }
    private func customEnabledBinding(_ exercise: CustomExerciseEntity) -> Binding<Bool> {
        .init(get: { !store.movement.disabledExerciseIDs.contains(exercise.id) }, set: { enabled in
            if enabled { store.movement.disabledExerciseIDs.remove(exercise.id) } else { store.movement.disabledExerciseIDs.insert(exercise.id) }
            store.persistSettings(); store.chooseNext()
        })
    }
    private func archive(_ exercise: CustomExerciseEntity) { exercise.archived = true; exercise.updatedAt = .now; try? modelContext.save() }
    private func duplicate(_ exercise: CustomExerciseEntity) {
        modelContext.insert(CustomExerciseEntity(name: "\(exercise.name) (copie)", emoji: exercise.emoji, category: ExerciseCategory(rawValue: exercise.categoryRaw) ?? .strength, metric: ExerciseMetric(rawValue: exercise.metricRaw) ?? .repetitions, defaultAmount: exercise.defaultAmount, instructions: exercise.instructions))
        try? modelContext.save()
    }
}

private struct NewExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = "💪"
    @State private var amount = 10
    @State private var category = ExerciseCategory.strength
    @State private var metric = ExerciseMetric.repetitions
    @State private var instructions = ""
    let onSave: (CustomExerciseEntity) -> Void
    var body: some View {
        Form {
            TextField("Nom", text: $name)
            TextField("Emoji", text: $emoji)
            Picker("Catégorie", selection: $category) { ForEach(ExerciseCategory.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            Picker("Mesure", selection: $metric) { Text("Répétitions").tag(ExerciseMetric.repetitions); Text("Secondes").tag(ExerciseMetric.seconds); Text("Minutes").tag(ExerciseMetric.minutes); Text("Libre").tag(ExerciseMetric.free) }
            Stepper("Quantité par défaut : \(amount)", value: $amount, in: 1...999)
            TextField("Consigne (optionnel)", text: $instructions, axis: .vertical)
            HStack { Spacer(); Button("Annuler") { dismiss() }; Button("Créer") { onSave(CustomExerciseEntity(name: name, emoji: emoji, category: category, metric: metric, defaultAmount: amount, instructions: instructions)); dismiss() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty).buttonStyle(.borderedProminent) }
        }.padding().frame(width: 400, height: 380)
    }
}

private struct EditExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var exercise: CustomExerciseEntity
    var body: some View {
        Form {
            TextField("Nom", text: $exercise.name)
            TextField("Emoji", text: $exercise.emoji)
            Stepper("Quantité par défaut : \(exercise.defaultAmount)", value: $exercise.defaultAmount, in: 1...999)
            TextField("Consigne", text: $exercise.instructions, axis: .vertical)
            Button("Terminer") { exercise.updatedAt = .now; dismiss() }.buttonStyle(.borderedProminent)
        }.padding().frame(width: 380, height: 300)
    }
}

struct SettingsView: View {
    @Bindable var store: MoveStore
    var body: some View {
        Form {
            Section("Jours actifs") {
                ForEach(1...7, id: \.self) { weekday in
                    Toggle(Calendar.current.shortWeekdaySymbols[weekday - 1], isOn: weekdayBinding(weekday))
                }
            }
            Section("Rappels") {
                Stepper("Toutes les \(store.reminder.intervalMinutes) minutes", value: $store.reminder.intervalMinutes, in: 15...180, step: 15)
                Stepper("Début à \(store.reminder.activeStartHour) h", value: $store.reminder.activeStartHour, in: 0...23)
                Stepper("Fin à \(store.reminder.activeEndHour) h", value: $store.reminder.activeEndHour, in: 1...24)
                Toggle("Afficher pendant les apps plein écran", isOn: $store.reminder.notificationsDuringFullScreen)
                Toggle("Afficher pendant les réunions", isOn: $store.reminder.notificationsDuringMeetings)
            }
            Section("Contraintes") { Toggle("Sans sauts", isOn: tagBinding("jump")); Toggle("Silencieux", isOn: tagBinding("noisy")); Toggle("Éviter le sol", isOn: tagBinding("floor")); Toggle("Éviter les poignets", isOn: tagBinding("wrists")); Toggle("Barre de traction disponible", isOn: equipmentBinding("pullup-bar")) }
            Section("Apparence et ambiance") {
                Picker("Afficher les rappels sur", selection: $store.appearance.screenTarget) {
                    Text("Écran principal").tag(ReminderScreenTarget.main)
                    Text("Écran actif").tag(ReminderScreenTarget.active)
                    Text("Écran du MacBook").tag(ReminderScreenTarget.macBook)
                }
                Picker("Humour", selection: $store.appearance.humor) {
                    Text("Normal").tag(HumorMode.normal)
                    Text("Discret").tag(HumorMode.discreet)
                    Text("Désactivé").tag(HumorMode.disabled)
                }
                Toggle("Emojis", isOn: $store.appearance.emojisEnabled)
                Picker("Animations", selection: $store.appearance.animations) {
                    Text("Complètes").tag(AnimationMode.full)
                    Text("Réduites").tag(AnimationMode.reduced)
                    Text("Désactivées").tag(AnimationMode.disabled)
                }
                Picker("Sons", selection: $store.appearance.sounds) {
                    Text("Aucun").tag(SoundMode.off)
                    Text("Discrets").tag(SoundMode.discreet)
                    Text("Normaux").tag(SoundMode.normal)
                }
            }
        }.formStyle(.grouped).padding().navigationTitle("Réglages")
        .onChange(of: store.reminder) { _, _ in store.persistSettings() }
        .onChange(of: store.movement) { _, _ in store.persistSettings(); store.chooseNext() }
        .onChange(of: store.appearance) { _, _ in store.persistSettings() }
    }
    private func weekdayBinding(_ weekday: Int) -> Binding<Bool> {
        Binding(get: { store.reminder.enabledWeekdays.contains(weekday) }, set: { enabled in
            if enabled { store.reminder.enabledWeekdays.insert(weekday) } else { store.reminder.enabledWeekdays.remove(weekday) }
        })
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
