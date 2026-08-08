import SwiftUI
import SwiftData
import MoveCore
import MoveShared

struct iOSMovementSettingsView: View {
    @Bindable var store: iOSAppStore
    @Environment(\.modelContext) private var modelContext
    @Query private var customExercises: [CustomExerciseEntity]
    @State private var search = ""
    @State private var category: ExerciseCategory?
    @State private var activeOnly = false
    @State private var showingNew = false
    @State private var editing: CustomExerciseEntity?

    var body: some View {
        List {
            Section("Intégrés") {
                ForEach(filteredBuiltIns) { exercise in
                    Toggle(isOn: enabledBinding(exercise.id)) {
                        exerciseLabel(exercise)
                    }
                }
            }
            Section("Personnalisés") {
                if visibleCustom.isEmpty {
                    Text("Aucun mouvement personnalisé")
                        .foregroundStyle(.secondary)
                }
                ForEach(visibleCustom) { entity in
                    HStack {
                        Toggle(isOn: enabledBinding(entity.id)) {
                            exerciseLabel(entity.exercise)
                        }
                        Button("Modifier", systemImage: "pencil") { editing = entity }
                            .labelStyle(.iconOnly)
                            .buttonStyle(.borderless)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Archiver", role: .destructive) { archive(entity) }
                        Button("Dupliquer") { duplicate(entity) }.tint(.blue)
                    }
                }
            }
        }
        .navigationTitle("Mouvements")
        .searchable(text: $search, prompt: "Rechercher")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Nouveau", systemImage: "plus") { showingNew = true }
            }
            ToolbarItem(placement: .topBarLeading) {
                Menu("Filtres", systemImage: "line.3.horizontal.decrease.circle") {
                    Picker("Catégorie", selection: $category) {
                        Text("Toutes").tag(nil as ExerciseCategory?)
                        ForEach(ExerciseCategory.allCases, id: \.self) {
                            Text(categoryLabel($0)).tag($0 as ExerciseCategory?)
                        }
                    }
                    Toggle("Actifs seulement", isOn: $activeOnly)
                }
            }
        }
        .sheet(isPresented: $showingNew) {
            iOSMovementEditorView(title: "Nouveau mouvement") { draft in
                modelContext.insert(draft.makeEntity())
                saveAndRefresh()
            }
        }
        .sheet(item: $editing) { entity in
            iOSMovementEditorView(title: "Modifier", draft: .init(entity: entity)) { draft in
                draft.apply(to: entity)
                saveAndRefresh()
            }
        }
    }

    private var filteredBuiltIns: [Exercise] {
        ExerciseLibrary.all.filter { exercise in
            matches(exercise)
                && (!activeOnly || !store.movement.disabledExerciseIDs.contains(exercise.id))
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var visibleCustom: [CustomExerciseEntity] {
        customExercises.filter { entity in
            guard !entity.archived, let exercise = entity.exercise else { return false }
            return matches(exercise)
                && (!activeOnly || !store.movement.disabledExerciseIDs.contains(entity.id))
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func matches(_ exercise: Exercise) -> Bool {
        (category == nil || exercise.category == category)
            && (search.isEmpty || exercise.name.localizedStandardContains(search))
    }

    @ViewBuilder private func exerciseLabel(_ exercise: Exercise?) -> some View {
        if let exercise {
            HStack {
                Text(exercise.emoji)
                VStack(alignment: .leading) {
                    Text(exercise.name)
                    Text("\(categoryLabel(exercise.category)) • difficulté \(exercise.difficulty)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func enabledBinding(_ id: String) -> Binding<Bool> {
        .init(
            get: { !store.movement.disabledExerciseIDs.contains(id) },
            set: { enabled in
                if enabled { store.movement.disabledExerciseIDs.remove(id) }
                else { store.movement.disabledExerciseIDs.insert(id) }
                store.persistSettings()
            }
        )
    }

    private func archive(_ entity: CustomExerciseEntity) {
        entity.archived = true
        entity.updatedAt = .now
        saveAndRefresh()
    }

    private func duplicate(_ entity: CustomExerciseEntity) {
        let draft = MovementDraft(entity: entity)
        var copy = draft
        copy.name += " copie"
        modelContext.insert(copy.makeEntity())
        saveAndRefresh()
    }

    private func saveAndRefresh() {
        try? modelContext.save()
        store.scheduleReminders(debounce: .zero)
    }

    private func categoryLabel(_ category: ExerciseCategory) -> String {
        switch category {
        case .strength: "Force"
        case .cardio: "Cardio"
        case .mobility: "Mobilité"
        case .stretch: "Étirement"
        case .recovery: "Récupération"
        case .free: "Libre"
        }
    }
}

private struct iOSMovementEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @State private var draft: MovementDraft
    let onSave: (MovementDraft) -> Void

    init(title: String, draft: MovementDraft = .init(), onSave: @escaping (MovementDraft) -> Void) {
        self.title = title
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identité") {
                    TextField("Nom", text: $draft.name)
                    TextField("Emoji", text: $draft.emoji)
                    Picker("Catégorie", selection: $draft.category) {
                        ForEach(ExerciseCategory.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    Picker("Mesure", selection: $draft.metric) {
                        Text("Répétitions").tag(ExerciseMetric.repetitions)
                        Text("Secondes").tag(ExerciseMetric.seconds)
                        Text("Minutes").tag(ExerciseMetric.minutes)
                        Text("Libre").tag(ExerciseMetric.free)
                    }
                    iOSSettingsStepper("Quantité", value: $draft.amount, in: 1...999)
                    iOSSettingsStepper("Difficulté", value: $draft.difficulty, in: 1...3)
                }
                Section("Équipement") {
                    Toggle("Chaise", isOn: setBinding("chair", set: $draft.equipment))
                    Toggle("Barre de traction", isOn: setBinding("pullup-bar", set: $draft.equipment))
                    Toggle("Élastique", isOn: setBinding("band", set: $draft.equipment))
                    Toggle("Haltères", isOn: setBinding("dumbbells", set: $draft.equipment))
                }
                Section("Contraintes") {
                    Toggle("Au sol", isOn: setBinding("floor", set: $draft.tags))
                    Toggle("Sauts", isOn: setBinding("jump", set: $draft.tags))
                    Toggle("Poignets", isOn: setBinding("wrists", set: $draft.tags))
                    Toggle("Bruyant", isOn: setBinding("noisy", set: $draft.tags))
                    Toggle("Genoux", isOn: setBinding("knees", set: $draft.tags))
                    Toggle("Dos", isOn: setBinding("back", set: $draft.tags))
                }
                Section("Zones musculaires") {
                    ForEach(["fullBody", "chest", "legs", "glutes", "back", "shoulders", "arms", "core"], id: \.self) { zone in
                        Toggle(zone, isOn: setBinding(zone, set: $draft.muscleZones))
                    }
                }
                Section("Instructions") {
                    TextField("Instructions facultatives", text: $draft.instructions, axis: .vertical)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { onSave(draft); dismiss() }
                        .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func setBinding(_ value: String, set: Binding<Set<String>>) -> Binding<Bool> {
        .init(
            get: { set.wrappedValue.contains(value) },
            set: { enabled in
                if enabled { set.wrappedValue.insert(value) }
                else { set.wrappedValue.remove(value) }
            }
        )
    }
}

private struct MovementDraft {
    var name = ""
    var emoji = "💪"
    var category = ExerciseCategory.strength
    var metric = ExerciseMetric.repetitions
    var amount = 10
    var difficulty = 1
    var instructions = ""
    var equipment: Set<String> = []
    var tags: Set<String> = []
    var muscleZones: Set<String> = []

    init() {}

    init(entity: CustomExerciseEntity) {
        name = entity.name
        emoji = entity.emoji
        category = ExerciseCategory(rawValue: entity.categoryRaw) ?? .strength
        metric = ExerciseMetric(rawValue: entity.metricRaw) ?? .repetitions
        amount = entity.defaultAmount
        difficulty = entity.exercise?.difficulty ?? 1
        instructions = entity.instructions
        equipment = entity.equipment
        tags = entity.tags.filter { !$0.hasPrefix("difficulty-") }
        muscleZones = entity.muscleZones
    }

    func makeEntity() -> CustomExerciseEntity {
        CustomExerciseEntity(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            emoji: emoji.isEmpty ? "💪" : emoji,
            category: category,
            metric: metric,
            defaultAmount: amount,
            instructions: instructions,
            equipment: equipment,
            tags: tags.union(["difficulty-\(difficulty)"]),
            muscleZones: muscleZones
        )
    }

    func apply(to entity: CustomExerciseEntity) {
        entity.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        entity.emoji = emoji.isEmpty ? "💪" : emoji
        entity.categoryRaw = category.rawValue
        entity.metricRaw = metric.rawValue
        entity.defaultAmount = amount
        entity.instructions = instructions
        entity.equipmentRaw = equipment.sorted().joined(separator: ",")
        entity.tagsRaw = tags.union(["difficulty-\(difficulty)"]).sorted().joined(separator: ",")
        entity.muscleZonesRaw = muscleZones.sorted().joined(separator: ",")
        entity.updatedAt = .now
    }
}
