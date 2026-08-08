import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import MoveCore
import MoveShared

struct MovementSettingsView: View {
    @Bindable var store: MoveStore
    @Environment(\.modelContext) private var modelContext
    @Query private var customExercises: [CustomExerciseEntity]
    @State private var search = ""
    @State private var categoryFilter: ExerciseCategory?
    @State private var equipmentFilter: String?
    @State private var difficultyFilter: Int?
    @State private var activeOnly = false
    @State private var showingNewExercise = false
    @State private var editingExercise: CustomExerciseEntity?
    var body: some View {
        List {
            if store.noCompatibleExercises {
                Section {
                    ContentUnavailableView(MoveCopy.text("exercise.noneActive"), systemImage: "exclamationmark.triangle", description: Text(MoveCopy.text("exercise.noneActiveMessage")))
                    Button(MoveCopy.text("exercise.enableAll")) { store.enableAllExercises() }
                        .buttonStyle(.borderedProminent)
                }
            }
            Section("Intégrés") {
                ForEach(filteredBuiltInExercises) { exercise in
            Toggle(isOn: Binding(get: { !store.movement.disabledExerciseIDs.contains(exercise.id) }, set: { enabled in if enabled { store.movement.disabledExerciseIDs.remove(exercise.id) } else { store.movement.disabledExerciseIDs.insert(exercise.id) } })) {
                HStack { Text(exercise.emoji); VStack(alignment: .leading) { Text(exercise.displayName); Text(exercise.category.rawValue).font(.caption).foregroundStyle(.secondary) } }
            }
                }
            }
            Section("Personnalisés") {
                ForEach(visibleCustomExercises) { exercise in
                    Toggle(isOn: customEnabledBinding(exercise)) {
                        HStack { Text(exercise.emoji); VStack(alignment: .leading) { Text(exercise.name); Text("\(exercise.categoryRaw) • \(exercise.metricRaw)").font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("\(exercise.defaultAmount)").foregroundStyle(.secondary) }
                    }
                    .contextMenu {
                        Button(MoveCopy.text("exercise.edit")) { editingExercise = exercise }
                        Button(MoveCopy.text("exercise.duplicate")) { duplicate(exercise) }
                        Button(MoveCopy.text("exercise.archive"), role: .destructive) { archive(exercise) }
                    }
                }.onDelete { offsets in
                    for index in offsets { archive(visibleCustomExercises[index]) }
                }
            }
        }.toolbar {
            Picker(MoveCopy.text("exercise.category"), selection: $categoryFilter) {
                Text(MoveCopy.text("exercise.allCategories")).tag(nil as ExerciseCategory?)
                ForEach(ExerciseCategory.allCases, id: \.self) { category in
                    Text(category.rawValue.capitalized).tag(category as ExerciseCategory?)
                }
            }
            Picker(MoveCopy.text("exercise.equipment"), selection: $equipmentFilter) {
                Text(MoveCopy.text("exercise.allEquipment")).tag(nil as String?)
                ForEach(allEquipment, id: \.self) { equipment in
                    Text(equipmentLabel(equipment)).tag(equipment as String?)
                }
            }
            Picker(MoveCopy.text("exercise.difficulty"), selection: $difficultyFilter) {
                Text(MoveCopy.text("exercise.allDifficulties")).tag(nil as Int?)
                Text(MoveCopy.text("exercise.easy")).tag(1 as Int?)
                Text(MoveCopy.text("exercise.intermediate")).tag(2 as Int?)
                Text(MoveCopy.text("exercise.hard")).tag(3 as Int?)
            }
            Toggle(MoveCopy.text("exercise.activeOnly"), isOn: $activeOnly)
            Button(MoveCopy.text("exercise.new"), systemImage: "plus") { showingNewExercise = true }
        }
        .sheet(isPresented: $showingNewExercise) { NewExerciseView { exercise in
            modelContext.insert(exercise)
            try? modelContext.save()
        } }
        .sheet(item: $editingExercise) { exercise in EditExerciseView(exercise: exercise) }
        .searchable(text: $search, prompt: MoveCopy.text("exercise.searchPrompt")).navigationTitle(MoveCopy.text("nav.movements"))
    }

    private var filteredBuiltInExercises: [Exercise] {
        ExerciseLibrary.all.filter {
            (categoryFilter == nil || $0.category == categoryFilter)
                && (equipmentFilter == nil || $0.equipment.contains(equipmentFilter!))
                && (difficultyFilter == nil || $0.difficulty == difficultyFilter)
                && (!activeOnly || !store.movement.disabledExerciseIDs.contains($0.id))
                && (search.isEmpty || $0.displayName.localizedStandardContains(search))
        }.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
    private var visibleCustomExercises: [CustomExerciseEntity] {
        customExercises.filter {
                !$0.archived
                && (categoryFilter == nil || $0.categoryRaw == categoryFilter?.rawValue)
                && (equipmentFilter == nil || $0.equipment.contains(equipmentFilter!))
                && (difficultyFilter == nil || $0.exercise?.difficulty == difficultyFilter)
                && (!activeOnly || !store.movement.disabledExerciseIDs.contains($0.id))
                && (search.isEmpty || $0.displayName.localizedStandardContains(search))
        }.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
    private var allEquipment: [String] {
        Set((ExerciseLibrary.all.flatMap(\.equipment) + customExercises.flatMap(\.equipment))).sorted()
    }
    private func equipmentLabel(_ value: String) -> String {
        switch value {
        case "chair": MoveCopy.text("equipment.chair")
        case "pullup-bar": MoveCopy.text("equipment.pullupBar")
        case "band": MoveCopy.text("equipment.band")
        case "dumbbells": MoveCopy.text("equipment.dumbbells")
        default: value
        }
    }
    private func customEnabledBinding(_ exercise: CustomExerciseEntity) -> Binding<Bool> {
        .init(get: { !store.movement.disabledExerciseIDs.contains(exercise.id) }, set: { enabled in
            if enabled { store.movement.disabledExerciseIDs.remove(exercise.id) } else { store.movement.disabledExerciseIDs.insert(exercise.id) }
            store.persistSettings(); store.chooseNext()
        })
    }
    private func archive(_ exercise: CustomExerciseEntity) { exercise.archived = true; exercise.updatedAt = .now; try? modelContext.save() }
    private func duplicate(_ exercise: CustomExerciseEntity) {
        modelContext.insert(CustomExerciseEntity(name: String(format: MoveCopy.text("workout.copyName"), exercise.displayName), emoji: exercise.emoji, category: ExerciseCategory(rawValue: exercise.categoryRaw) ?? .strength, metric: ExerciseMetric(rawValue: exercise.metricRaw) ?? .repetitions, defaultAmount: exercise.defaultAmount, instructions: exercise.instructions, equipment: exercise.equipment, tags: exercise.tags.subtracting(["personnalisé"]), muscleZones: exercise.muscleZones))
        try? modelContext.save()
    }
}

private struct NewExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = "💪"
    @State private var amount = 10
    @State private var category = ExerciseCategory.strength
    @State private var difficulty = 1
    @State private var metric = ExerciseMetric.repetitions
    @State private var instructions = ""
    @State private var easierVariantID = ""
    @State private var harderVariantID = ""
    @State private var equipment: Set<String> = []
    @State private var tags: Set<String> = []
    @State private var muscleZones: Set<String> = []
    let onSave: (CustomExerciseEntity) -> Void
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                Form {
                    TextField(MoveCopy.text("exercise.name"), text: $name)
                    TextField(MoveCopy.text("exercise.emoji"), text: $emoji)
                    Picker(MoveCopy.text("exercise.category"), selection: $category) { ForEach(ExerciseCategory.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    Picker(MoveCopy.text("exercise.difficulty"), selection: $difficulty) {
                        Text(MoveCopy.text("exercise.easy")).tag(1)
                        Text(MoveCopy.text("exercise.intermediate")).tag(2)
                        Text(MoveCopy.text("exercise.hard")).tag(3)
                    }
                    Picker(MoveCopy.text("exercise.metric"), selection: $metric) { Text(MoveCopy.text("exercise.repetitions")).tag(ExerciseMetric.repetitions); Text(MoveCopy.text("exercise.seconds")).tag(ExerciseMetric.seconds); Text(MoveCopy.text("exercise.minutes")).tag(ExerciseMetric.minutes); Text(MoveCopy.text("exercise.free")).tag(ExerciseMetric.free) }
                    Stepper(String(format: MoveCopy.text("exercise.defaultAmount"), amount), value: $amount, in: 1...999)
                    Section(MoveCopy.text("exercise.equipment")) {
                        Toggle(MoveCopy.text("equipment.chair"), isOn: setBinding("chair", in: $equipment))
                        Toggle(MoveCopy.text("equipment.pullupBar"), isOn: setBinding("pullup-bar", in: $equipment))
                        Toggle(MoveCopy.text("equipment.band"), isOn: setBinding("band", in: $equipment))
                        Toggle(MoveCopy.text("equipment.dumbbells"), isOn: setBinding("dumbbells", in: $equipment))
                    }
                    Section(MoveCopy.text("exercise.constraints")) {
                        Toggle(MoveCopy.text("constraint.floor"), isOn: setBinding("floor", in: $tags))
                        Toggle(MoveCopy.text("constraint.jump"), isOn: setBinding("jump", in: $tags))
                        Toggle(MoveCopy.text("constraint.wrists"), isOn: setBinding("wrists", in: $tags))
                        Toggle(MoveCopy.text("constraint.noisy"), isOn: setBinding("noisy", in: $tags))
                        Toggle(MoveCopy.text("constraint.knees"), isOn: setBinding("knees", in: $tags))
                        Toggle(MoveCopy.text("constraint.back"), isOn: setBinding("back", in: $tags))
                        Toggle(MoveCopy.text("constraint.space"), isOn: setBinding("space", in: $tags))
                    }
                    Section(MoveCopy.text("exercise.muscleZones")) {
                        Toggle(MoveCopy.text("zone.fullBody"), isOn: setBinding("fullBody", in: $muscleZones))
                        Toggle(MoveCopy.text("zone.chest"), isOn: setBinding("chest", in: $muscleZones))
                        Toggle(MoveCopy.text("zone.legs"), isOn: setBinding("legs", in: $muscleZones))
                        Toggle(MoveCopy.text("zone.glutes"), isOn: setBinding("glutes", in: $muscleZones))
                        Toggle(MoveCopy.text("zone.back"), isOn: setBinding("back", in: $muscleZones))
                        Toggle(MoveCopy.text("zone.shoulders"), isOn: setBinding("shoulders", in: $muscleZones))
                        Toggle(MoveCopy.text("zone.arms"), isOn: setBinding("arms", in: $muscleZones))
                        Toggle(MoveCopy.text("zone.core"), isOn: setBinding("core", in: $muscleZones))
                        Toggle(MoveCopy.text("zone.calves"), isOn: setBinding("calves", in: $muscleZones))
                        Toggle(MoveCopy.text("zone.neck"), isOn: setBinding("neck", in: $muscleZones))
                        Toggle(MoveCopy.text("zone.wrists"), isOn: setBinding("wrists", in: $muscleZones))
                        Toggle(MoveCopy.text("zone.hips"), isOn: setBinding("hips", in: $muscleZones))
                    }
                    TextField(MoveCopy.text("exercise.instructionsOptional"), text: $instructions, axis: .vertical)
                    Section(MoveCopy.text("exercise.variants")) {
                        TextField(MoveCopy.text("exercise.easierVariantID"), text: $easierVariantID)
                        TextField(MoveCopy.text("exercise.harderVariantID"), text: $harderVariantID)
                    }
                }
                .formStyle(.grouped)
                .fixedSize(horizontal: false, vertical: true)
            }
            .defaultScrollAnchor(.top)
            Divider()
            HStack {
                Spacer()
                Button(MoveCopy.text("common.cancel")) { dismiss() }
                Button(MoveCopy.text("common.create")) { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 520, height: 620)
    }

    private func save() {
        let variantTags = Set([easierVariantID.isEmpty ? "" : "easier-\(easierVariantID)", harderVariantID.isEmpty ? "" : "harder-\(harderVariantID)"]).filter { !$0.isEmpty }
        onSave(CustomExerciseEntity(name: name, emoji: emoji, category: category, metric: metric, defaultAmount: amount, instructions: instructions, equipment: equipment, tags: tags.union(variantTags).union(["difficulty-\(difficulty)"]), muscleZones: muscleZones))
        dismiss()
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
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                Form {
                    TextField(MoveCopy.text("exercise.name"), text: $exercise.name)
                    TextField(MoveCopy.text("exercise.emoji"), text: $exercise.emoji)
                    Picker(MoveCopy.text("exercise.category"), selection: $exercise.categoryRaw) {
                        ForEach(ExerciseCategory.allCases, id: \.rawValue) { category in
                            Text(category.rawValue.capitalized).tag(category.rawValue)
                        }
                    }
                    Picker(MoveCopy.text("exercise.metric"), selection: $exercise.metricRaw) {
                        Text(MoveCopy.text("exercise.repetitions")).tag(ExerciseMetric.repetitions.rawValue)
                        Text(MoveCopy.text("exercise.seconds")).tag(ExerciseMetric.seconds.rawValue)
                        Text(MoveCopy.text("exercise.minutes")).tag(ExerciseMetric.minutes.rawValue)
                        Text(MoveCopy.text("exercise.free")).tag(ExerciseMetric.free.rawValue)
                    }
                    Picker(MoveCopy.text("exercise.difficulty"), selection: difficultyBinding) {
                        Text(MoveCopy.text("exercise.easy")).tag(1)
                        Text(MoveCopy.text("exercise.intermediate")).tag(2)
                        Text(MoveCopy.text("exercise.hard")).tag(3)
                    }
                    Stepper(String(format: MoveCopy.text("exercise.defaultAmount"), exercise.defaultAmount), value: $exercise.defaultAmount, in: 1...999)
                    Section(MoveCopy.text("exercise.equipment")) {
                        Toggle(MoveCopy.text("equipment.chair"), isOn: equipmentBinding("chair"))
                        Toggle(MoveCopy.text("equipment.pullupBar"), isOn: equipmentBinding("pullup-bar"))
                        Toggle(MoveCopy.text("equipment.band"), isOn: equipmentBinding("band"))
                        Toggle(MoveCopy.text("equipment.dumbbells"), isOn: equipmentBinding("dumbbells"))
                    }
                    Section(MoveCopy.text("exercise.constraints")) {
                        Toggle(MoveCopy.text("constraint.floor"), isOn: tagBinding("floor"))
                        Toggle(MoveCopy.text("constraint.jump"), isOn: tagBinding("jump"))
                        Toggle(MoveCopy.text("constraint.wrists"), isOn: tagBinding("wrists"))
                        Toggle(MoveCopy.text("constraint.noisy"), isOn: tagBinding("noisy"))
                        Toggle(MoveCopy.text("constraint.knees"), isOn: tagBinding("knees"))
                        Toggle(MoveCopy.text("constraint.back"), isOn: tagBinding("back"))
                        Toggle(MoveCopy.text("constraint.space"), isOn: tagBinding("space"))
                    }
                    Section(MoveCopy.text("exercise.muscleZones")) {
                        Toggle(MoveCopy.text("zone.fullBody"), isOn: zoneBinding("fullBody"))
                        Toggle(MoveCopy.text("zone.chest"), isOn: zoneBinding("chest"))
                        Toggle(MoveCopy.text("zone.legs"), isOn: zoneBinding("legs"))
                        Toggle(MoveCopy.text("zone.glutes"), isOn: zoneBinding("glutes"))
                        Toggle(MoveCopy.text("zone.back"), isOn: zoneBinding("back"))
                        Toggle(MoveCopy.text("zone.shoulders"), isOn: zoneBinding("shoulders"))
                        Toggle(MoveCopy.text("zone.arms"), isOn: zoneBinding("arms"))
                        Toggle(MoveCopy.text("zone.core"), isOn: zoneBinding("core"))
                        Toggle(MoveCopy.text("zone.calves"), isOn: zoneBinding("calves"))
                        Toggle(MoveCopy.text("zone.neck"), isOn: zoneBinding("neck"))
                        Toggle(MoveCopy.text("zone.wrists"), isOn: zoneBinding("wrists"))
                        Toggle(MoveCopy.text("zone.hips"), isOn: zoneBinding("hips"))
                    }
                    TextField(MoveCopy.text("exercise.instructions"), text: $exercise.instructions, axis: .vertical)
                    Section(MoveCopy.text("exercise.variants")) {
                        TextField(MoveCopy.text("exercise.easierVariantID"), text: variantBinding(prefix: "easier-"))
                        TextField(MoveCopy.text("exercise.harderVariantID"), text: variantBinding(prefix: "harder-"))
                    }
                }
                .formStyle(.grouped)
                .fixedSize(horizontal: false, vertical: true)
            }
            .defaultScrollAnchor(.top)
            Divider()
            HStack {
                Spacer()
                Button(MoveCopy.text("common.done")) { exercise.updatedAt = .now; dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 520, height: 620)
    }

    private func tagBinding(_ tag: String) -> Binding<Bool> {
        Binding(get: { exercise.tags.contains(tag) }, set: { enabled in
            var tags = exercise.tags
            if enabled { tags.insert(tag) } else { tags.remove(tag) }
            exercise.tagsRaw = tags.sorted().joined(separator: ",")
            exercise.updatedAt = .now
        })
    }

    private var difficultyBinding: Binding<Int> {
        Binding(get: { exercise.exercise?.difficulty ?? 1 }, set: { value in
            var tags = exercise.tags.filter { !$0.hasPrefix("difficulty-") }
            tags.insert("difficulty-\(value)")
            exercise.tagsRaw = tags.sorted().joined(separator: ",")
            exercise.updatedAt = .now
        })
    }

    private func equipmentBinding(_ equipment: String) -> Binding<Bool> {
        Binding(get: { exercise.equipment.contains(equipment) }, set: { enabled in
            var values = exercise.equipment
            if enabled { values.insert(equipment) } else { values.remove(equipment) }
            exercise.equipmentRaw = values.sorted().joined(separator: ",")
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

    private func variantBinding(prefix: String) -> Binding<String> {
        Binding(get: {
            exercise.tags.first(where: { $0.hasPrefix(prefix) }).map { String($0.dropFirst(prefix.count)) } ?? ""
        }, set: { value in
            var tags = exercise.tags.filter { !$0.hasPrefix(prefix) }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { tags.insert(prefix + trimmed) }
            exercise.tagsRaw = tags.sorted().joined(separator: ",")
            exercise.updatedAt = .now
        })
    }
}

struct SettingsView: View {
    @Bindable var store: MoveStore
    @Environment(\.modelContext) private var modelContext
    @Query private var customExercises: [CustomExerciseEntity]
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
                Toggle(MoveCopy.text("settings.remindersEnabled"), isOn: $store.reminder.enabled)
                Stepper(String(format: MoveCopy.text("settings.interval"), store.reminder.intervalMinutes), value: $store.reminder.intervalMinutes, in: 15...180, step: 15)
                Stepper(String(format: MoveCopy.text("settings.snoozeDefault"), store.reminder.snoozeMinutes), value: $store.reminder.snoozeMinutes, in: 15...60, step: 15)
                Stepper(String(format: MoveCopy.text("settings.startHour"), store.reminder.activeStartHour), value: $store.reminder.activeStartHour, in: 0...23)
                Stepper(String(format: MoveCopy.text("settings.endHour"), store.reminder.activeEndHour), value: $store.reminder.activeEndHour, in: 1...24)
                Toggle(MoveCopy.text("settings.fullScreen"), isOn: $store.reminder.notificationsDuringFullScreen)
                Toggle(MoveCopy.text("settings.meetings"), isOn: $store.reminder.notificationsDuringMeetings)
            }
            Section("Grease the Groove") {
                Toggle("Activer ce mode", isOn: $store.reminder.greaseTheGrooveEnabled)
                if store.reminder.greaseTheGrooveEnabled {
                    Picker("Mouvement", selection: Binding(
                        get: { store.reminder.greaseTheGrooveExerciseID ?? allExercises.first?.id ?? "" },
                        set: { store.reminder.greaseTheGrooveExerciseID = $0 }
                    )) {
                        ForEach(allExercises, id: \.id) { exercise in
                            Text("\(exercise.emoji) \(exercise.displayName)").tag(exercise.id)
                        }
                    }
                    Stepper("Rep max : \(store.reminder.greaseTheGrooveRepMax)", value: $store.reminder.greaseTheGrooveRepMax, in: 1...200)
                    Stepper("Pourcentage : \(store.reminder.greaseTheGroovePercentage)%", value: $store.reminder.greaseTheGroovePercentage, in: 10...90, step: 5)
                    Stepper("Réétalonnage : tous les \(store.reminder.greaseTheGrooveCalibrationIntervalDays) jours", value: $store.reminder.greaseTheGrooveCalibrationIntervalDays, in: 7...90, step: 7)
                    Text("Chaque rappel propose uniquement ce mouvement à \(max(1, store.reminder.greaseTheGrooveRepMax * store.reminder.greaseTheGroovePercentage / 100)) répétitions.")
                        .font(.caption).foregroundStyle(.secondary)
                    if needsCalibration { Text("⚠️ Rep max à réétalonner").foregroundStyle(.orange) }
                    Button("Marquer la rep max comme étalonnée") { store.reminder.greaseTheGrooveLastCalibratedAt = .now }
                }
            }
            Section("Appareil hôte des rappels") {
                Picker("Programmer les notifications sur", selection: $store.reminderHost) {
                    Text("iPhone et Apple Watch").tag(ReminderHostPreference.phoneAndWatch)
                    Text("Mac").tag(ReminderHostPreference.mac)
                    Text("Tous les appareils (doublons possibles)").tag(ReminderHostPreference.all)
                }
                Text("L’Apple Watch suit toujours la file programmée par l’iPhone.").font(.caption).foregroundStyle(.secondary)
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
        }.formStyle(.grouped).padding().navigationTitle(MoveCopy.text("settings.title"))
        .fileExporter(isPresented: $exportingDiagnostic, document: diagnosticDocument, contentType: .json, defaultFilename: "move-diagnostic.json") { _ in }
        .onChange(of: store.reminder) { _, _ in store.persistSettings(); store.scheduleNextReminder() }
        .onChange(of: store.movement) { _, _ in store.persistSettings(); store.chooseNext(); store.scheduleNextReminder() }
        .onChange(of: store.appearance) { _, _ in store.persistSettings(); store.scheduleNextReminder() }
        .onChange(of: store.reminderHost) { _, _ in store.persistSettings(); store.scheduleNextReminder() }
        .onAppear { launchAtLogin = LaunchAtLoginService.isEnabled }
        .alert(item: $pendingDataAction) { action in
            Alert(title: Text(action.title), message: Text(action.message),
                  primaryButton: .destructive(Text(MoveCopy.text("common.confirm"))) {
                      switch action { case .resetSettings: store.resetSettings(); case .deleteAll: store.deleteAllData() }
                  }, secondaryButton: .cancel(Text(MoveCopy.text("common.cancel"))))
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLoginService.setEnabled(enabled)
            launchError = nil
            launchAtLogin = LaunchAtLoginService.isEnabled
        } catch {
            launchAtLogin = LaunchAtLoginService.isEnabled
            launchError = String(format: MoveCopy.text("settings.launchError"), error.localizedDescription)
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

    private var allExercises: [Exercise] {
        ExerciseLibrary.all + customExercises.filter { !$0.archived }.compactMap(\.exercise)
    }

    private var needsCalibration: Bool {
        guard let date = store.reminder.greaseTheGrooveLastCalibratedAt,
              let due = Calendar.current.date(byAdding: .day, value: store.reminder.greaseTheGrooveCalibrationIntervalDays, to: date)
        else { return true }
        return due <= .now
    }
}
