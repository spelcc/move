import SwiftUI
import SwiftData
import UniformTypeIdentifiers
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
        modelContext.insert(CustomExerciseEntity(name: "\(exercise.name) (copie)", emoji: exercise.emoji, category: ExerciseCategory(rawValue: exercise.categoryRaw) ?? .strength, metric: ExerciseMetric(rawValue: exercise.metricRaw) ?? .repetitions, defaultAmount: exercise.defaultAmount, instructions: exercise.instructions, equipment: exercise.equipment, tags: exercise.tags.subtracting(["personnalisé"]), muscleZones: exercise.muscleZones))
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
    @State private var equipment: Set<String> = []
    @State private var tags: Set<String> = []
    @State private var muscleZones: Set<String> = []
    let onSave: (CustomExerciseEntity) -> Void
    var body: some View {
        Form {
            TextField("Nom", text: $name)
            TextField("Emoji", text: $emoji)
            Picker("Catégorie", selection: $category) { ForEach(ExerciseCategory.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            Picker("Mesure", selection: $metric) { Text("Répétitions").tag(ExerciseMetric.repetitions); Text("Secondes").tag(ExerciseMetric.seconds); Text("Minutes").tag(ExerciseMetric.minutes); Text("Libre").tag(ExerciseMetric.free) }
            Stepper("Quantité par défaut : \(amount)", value: $amount, in: 1...999)
            Section("Matériel") {
                Toggle("Chaise", isOn: setBinding("chair", in: $equipment))
                Toggle("Barre de traction", isOn: setBinding("pullup-bar", in: $equipment))
                Toggle("Élastique", isOn: setBinding("band", in: $equipment))
                Toggle("Haltères", isOn: setBinding("dumbbells", in: $equipment))
            }
            Section("Contraintes") {
                Toggle("Au sol", isOn: setBinding("floor", in: $tags))
                Toggle("Avec sauts", isOn: setBinding("jump", in: $tags))
                Toggle("Sollicite les poignets", isOn: setBinding("wrists", in: $tags))
                Toggle("Bruyant", isOn: setBinding("noisy", in: $tags))
            }
            Section("Zones musculaires") {
                Toggle("Jambes", isOn: setBinding("legs", in: $muscleZones))
                Toggle("Fessiers", isOn: setBinding("glutes", in: $muscleZones))
                Toggle("Dos", isOn: setBinding("back", in: $muscleZones))
                Toggle("Épaules", isOn: setBinding("shoulders", in: $muscleZones))
                Toggle("Bras", isOn: setBinding("arms", in: $muscleZones))
                Toggle("Centre du corps", isOn: setBinding("core", in: $muscleZones))
            }
            TextField("Consigne (optionnel)", text: $instructions, axis: .vertical)
            HStack { Spacer(); Button("Annuler") { dismiss() }; Button("Créer") { onSave(CustomExerciseEntity(name: name, emoji: emoji, category: category, metric: metric, defaultAmount: amount, instructions: instructions, equipment: equipment, tags: tags, muscleZones: muscleZones)); dismiss() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty).buttonStyle(.borderedProminent) }
        }.padding().frame(width: 420, height: 620)
    }

    private func setBinding(_ value: String, in set: Binding<Set<String>>) -> Binding<Bool> {
        Binding(get: { set.wrappedValue.contains(value) }, set: { enabled in
            if enabled { set.wrappedValue.insert(value) } else { set.wrappedValue.remove(value) }
        })
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
            Section("Contraintes") {
                Toggle("Au sol", isOn: tagBinding("floor"))
                Toggle("Avec sauts", isOn: tagBinding("jump"))
                Toggle("Sollicite les poignets", isOn: tagBinding("wrists"))
                Toggle("Bruyant", isOn: tagBinding("noisy"))
            }
            Section("Zones musculaires") {
                Toggle("Jambes", isOn: zoneBinding("legs"))
                Toggle("Fessiers", isOn: zoneBinding("glutes"))
                Toggle("Dos", isOn: zoneBinding("back"))
                Toggle("Épaules", isOn: zoneBinding("shoulders"))
                Toggle("Bras", isOn: zoneBinding("arms"))
                Toggle("Centre du corps", isOn: zoneBinding("core"))
            }
            TextField("Consigne", text: $exercise.instructions, axis: .vertical)
            Button("Terminer") { exercise.updatedAt = .now; dismiss() }.buttonStyle(.borderedProminent)
        }.padding().frame(width: 380, height: 430)
    }

    private func tagBinding(_ tag: String) -> Binding<Bool> {
        Binding(get: { exercise.tags.contains(tag) }, set: { enabled in
            var tags = exercise.tags
            if enabled { tags.insert(tag) } else { tags.remove(tag) }
            exercise.tagsRaw = tags.sorted().joined(separator: ",")
            exercise.updatedAt = .now
        })
    }

    private func zoneBinding(_ zone: String) -> Binding<Bool> {
        Binding(get: { exercise.muscleZones.contains(zone) }, set: { enabled in
            var zones = exercise.muscleZones
            if enabled { zones.insert(zone) } else { zones.remove(zone) }
            exercise.muscleZonesRaw = zones.sorted().joined(separator: ",")
            exercise.updatedAt = .now
        })
    }
}

struct SettingsView: View {
    @Bindable var store: MoveStore
    @Environment(\.modelContext) private var modelContext
    @State private var pendingDataAction: DataAction?
    @State private var launchAtLogin = false
    @State private var launchError: String?
    @State private var exportingDiagnostic = false
    @State private var diagnosticDocument = DiagnosticDocument()

    private enum DataAction: Identifiable {
        case resetSettings, deleteAll
        var id: String { String(describing: self) }
        var title: String {
            switch self { case .resetSettings: "Réinitialiser les réglages ?"; case .deleteAll: "Supprimer toutes les données ?" }
        }
        var message: String {
            switch self {
            case .resetSettings: "Les préférences de rappels, mouvements et apparence seront restaurées par défaut."
            case .deleteAll: "L’historique, les séances et les mouvements personnalisés seront supprimés définitivement."
            }
        }
    }

    var body: some View {
        Form {
            Section(MoveCopy.text("settings.general")) {
                Toggle(MoveCopy.text("settings.launchAtLogin"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let launchError { Text(launchError).font(.caption).foregroundStyle(.red) }
            }
            Section(MoveCopy.text("settings.activeDays")) {
                ForEach(1...7, id: \.self) { weekday in
                    Toggle(Calendar.current.shortWeekdaySymbols[weekday - 1], isOn: weekdayBinding(weekday))
                }
            }
            Section(MoveCopy.text("settings.reminders")) {
                Stepper("Toutes les \(store.reminder.intervalMinutes) minutes", value: $store.reminder.intervalMinutes, in: 15...180, step: 15)
                Stepper("Début à \(store.reminder.activeStartHour) h", value: $store.reminder.activeStartHour, in: 0...23)
                Stepper("Fin à \(store.reminder.activeEndHour) h", value: $store.reminder.activeEndHour, in: 1...24)
                Toggle(MoveCopy.text("settings.fullScreen"), isOn: $store.reminder.notificationsDuringFullScreen)
                Toggle(MoveCopy.text("settings.meetings"), isOn: $store.reminder.notificationsDuringMeetings)
            }
            Section(MoveCopy.text("settings.constraints")) { Toggle(MoveCopy.text("settings.noJumps"), isOn: tagBinding("jump")); Toggle(MoveCopy.text("settings.quiet"), isOn: tagBinding("noisy")); Toggle(MoveCopy.text("settings.avoidFloor"), isOn: tagBinding("floor")); Toggle(MoveCopy.text("settings.avoidWrists"), isOn: tagBinding("wrists")); Toggle(MoveCopy.text("settings.pullupBar"), isOn: equipmentBinding("pullup-bar")) }
            Section(MoveCopy.text("settings.appearance")) {
                Picker(MoveCopy.text("settings.screenTarget"), selection: $store.appearance.screenTarget) {
                    Text(MoveCopy.text("settings.mainScreen")).tag(ReminderScreenTarget.main)
                    Text(MoveCopy.text("settings.activeScreen")).tag(ReminderScreenTarget.active)
                    Text(MoveCopy.text("settings.macBookScreen")).tag(ReminderScreenTarget.macBook)
                }
                Picker(MoveCopy.text("settings.humor"), selection: $store.appearance.humor) {
                    Text(MoveCopy.text("settings.normal")).tag(HumorMode.normal)
                    Text(MoveCopy.text("settings.discreet")).tag(HumorMode.discreet)
                    Text(MoveCopy.text("settings.disabled")).tag(HumorMode.disabled)
                }
                Toggle(MoveCopy.text("settings.emojis"), isOn: $store.appearance.emojisEnabled)
                Picker(MoveCopy.text("settings.animations"), selection: $store.appearance.animations) {
                    Text(MoveCopy.text("settings.full")).tag(AnimationMode.full)
                    Text(MoveCopy.text("settings.reduced")).tag(AnimationMode.reduced)
                    Text(MoveCopy.text("settings.disabled")).tag(AnimationMode.disabled)
                }
                Picker(MoveCopy.text("settings.sounds"), selection: $store.appearance.sounds) {
                    Text(MoveCopy.text("settings.none")).tag(SoundMode.off)
                    Text(MoveCopy.text("settings.discreet")).tag(SoundMode.discreet)
                    Text(MoveCopy.text("settings.normal")).tag(SoundMode.normal)
                }
            }
            Section(MoveCopy.text("settings.data")) {
                Button(MoveCopy.text("settings.exportDiagnostic"), systemImage: "stethoscope") {
                    diagnosticDocument = DiagnosticDocument(report: MoveDiagnosticReport.make(context: modelContext, store: store, persistenceIssue: nil))
                    exportingDiagnostic = true
                }
                Button(MoveCopy.text("settings.reset")) { pendingDataAction = .resetSettings }
                Button(MoveCopy.text("settings.deleteAll"), role: .destructive) { pendingDataAction = .deleteAll }
            }
        }.formStyle(.grouped).padding().navigationTitle("Réglages")
        .fileExporter(isPresented: $exportingDiagnostic, document: diagnosticDocument, contentType: .json, defaultFilename: "move-diagnostic.json") { _ in }
        .onChange(of: store.reminder) { _, _ in store.persistSettings() }
        .onChange(of: store.movement) { _, _ in store.persistSettings(); store.chooseNext() }
        .onChange(of: store.appearance) { _, _ in store.persistSettings() }
        .onAppear { launchAtLogin = LaunchAtLoginService.isEnabled }
        .alert(item: $pendingDataAction) { action in
            Alert(title: Text(action.title), message: Text(action.message),
                  primaryButton: .destructive(Text("Confirmer")) {
                      switch action { case .resetSettings: store.resetSettings(); case .deleteAll: store.deleteAllData() }
                  }, secondaryButton: .cancel(Text("Annuler")))
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginService.setEnabled(enabled)
            launchError = nil
            launchAtLogin = LaunchAtLoginService.isEnabled
        } catch {
            launchAtLogin = LaunchAtLoginService.isEnabled
            launchError = "Lancement automatique indisponible : \(error.localizedDescription)"
        }
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
