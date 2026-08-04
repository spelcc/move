import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import MoveCore

struct WorkoutLibraryView: View {
    @Bindable var store: MoveStore
    @Environment(\.modelContext) private var modelContext
    @Query private var customWorkouts: [WorkoutTemplateEntity]
    @State private var showingEditor = false
    @State private var previewing: WorkoutTemplate?
    @State private var renaming: WorkoutTemplateEntity?
    @State private var editingWorkout: WorkoutTemplateEntity?
    @State private var exportingTemplates = false
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(MoveCopy.text("nav.workouts")).font(.title.bold())
                Spacer()
                Button(MoveCopy.text("workouts.export"), systemImage: "square.and.arrow.up") { exportingTemplates = true }
                Button(MoveCopy.text("workouts.create"), systemImage: "plus") { showingEditor = true }
            }
            if let saved = store.resumableWorkout, let workout = resumableWorkout(saved) {
                Button("\(MoveCopy.text("workouts.resume")) \(workout.name)") { store.resume(workout) }
                    .buttonStyle(.borderedProminent)
            }
            LazyVGrid(columns: [.init(.adaptive(minimum: 230))], spacing: 16) {
            if customWorkouts.filter({ !$0.archived }).isEmpty {
                ContentUnavailableView(MoveCopy.text("empty.workouts.title"), systemImage: "timer", description: Text(MoveCopy.text("empty.workouts.message")))
                    .frame(maxWidth: .infinity)
            }
            ForEach(customWorkouts.filter { !$0.archived }) { entity in
                if let workout = entity.template {
                    workoutCard(workout)
                        .contextMenu {
                            Button(MoveCopy.text("workouts.duplicate")) { duplicate(entity) }
                            Button(MoveCopy.text("workouts.edit")) { editingWorkout = entity }
                            Button(MoveCopy.text("workouts.rename")) { renaming = entity }
                            Button(MoveCopy.text("workouts.archive")) { archive(entity) }
                            Button(MoveCopy.text("workouts.delete"), role: .destructive) { delete(entity) }
                        }
                }
            }
            ForEach(ExerciseLibrary.quickWorkouts) { workout in
                Button { previewing = workout } label: {
                    VStack(alignment: .leading, spacing: 8) { Text(workout.name).font(.title3.bold()); Text("\(workout.estimatedDuration / 60) min • \(workout.rounds) \(MoveCopy.text("workouts.rounds"))").foregroundStyle(.secondary); Text(MoveCopy.text("workouts.start")).font(.callout.bold()) }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(.plain)
            }
            }
        }.padding(28) }
        .overlay {
            if let workout = store.activeWorkout {
                WorkoutRunnerView(store: store, workout: workout)
            } else if let workout = store.completedWorkout {
                WorkoutCompletionView(workout: workout) { store.dismissCompletion() }
            }
        }
        .sheet(isPresented: $showingEditor) { WorkoutEditorView { template in
            modelContext.insert(WorkoutTemplateEntity(template: template)); try? modelContext.save()
        } }
        .sheet(item: $editingWorkout) { entity in
            WorkoutEditorView(template: entity.template) { template in
                entity.id = template.id
                entity.name = template.name
                entity.templateData = (try? JSONEncoder().encode(template)) ?? entity.templateData
                entity.updatedAt = .now
                try? modelContext.save()
            }
        }
        .sheet(item: $previewing) { workout in
            WorkoutSummaryView(workout: workout) { store.start(workout); previewing = nil }
        }
        .sheet(item: $renaming) { entity in
            WorkoutRenameView(entity: entity)
        }
        .fileExporter(
            isPresented: $exportingTemplates,
            document: WorkoutTemplatesDocument(templates: customWorkouts.compactMap(\.template)),
            contentType: .json,
            defaultFilename: "move-workouts.json"
        ) { _ in }
    }

    private func workoutCard(_ workout: WorkoutTemplate) -> some View {
        Button { previewing = workout } label: {
            VStack(alignment: .leading, spacing: 8) { Text(workout.name).font(.title3.bold()); Text("\(workout.estimatedDuration / 60) min • \(workout.rounds) \(MoveCopy.text("workouts.rounds"))").foregroundStyle(.secondary); Text(MoveCopy.text("workouts.start")).font(.callout.bold()) }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain)
    }

    private func resumableWorkout(_ session: WorkoutSessionEntity) -> WorkoutTemplate? {
        if let builtIn = ExerciseLibrary.quickWorkouts.first(where: { $0.id == session.workoutID }) { return builtIn }
        return customWorkouts.first(where: { $0.id == session.workoutID && !$0.archived })?.template
    }

    private func archive(_ entity: WorkoutTemplateEntity) {
        entity.archived = true
        entity.updatedAt = .now
        try? modelContext.save()
    }

    private func delete(_ entity: WorkoutTemplateEntity) {
        modelContext.delete(entity)
        try? modelContext.save()
    }

    private func duplicate(_ entity: WorkoutTemplateEntity) {
        guard let template = entity.template else { return }
        let copy = WorkoutTemplate(id: UUID(), name: "\(template.name) (copie)", description: template.description, emoji: template.emoji, rounds: template.rounds, preparationSeconds: template.preparationSeconds, roundRestSeconds: template.roundRestSeconds, finalRecoverySeconds: template.finalRecoverySeconds, steps: template.steps, mode: template.mode)
        modelContext.insert(WorkoutTemplateEntity(template: copy))
        try? modelContext.save()
    }
}

private struct WorkoutTemplatesDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var templates: [WorkoutTemplate]

    init(templates: [WorkoutTemplate] = []) { self.templates = templates }
    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        templates = try JSONDecoder().decode([WorkoutTemplate].self, from: data)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(templates)
        return FileWrapper(regularFileWithContents: data)
    }
}

private struct WorkoutRenameView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var entity: WorkoutTemplateEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Renommer la séance").font(.title2.bold())
            TextField("Nom", text: $entity.name)
            HStack {
                Spacer()
                Button("Annuler") { dismiss() }
                Button("Enregistrer") {
                    entity.name = entity.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    entity.updatedAt = .now
                    try? modelContext.save()
                    dismiss()
                }.buttonStyle(.borderedProminent)
                    .disabled(entity.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 360)
    }
}

private struct WorkoutCompletionView: View {
    let workout: WorkoutTemplate
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(.green)
                Text("Séance terminée").font(.largeTitle.bold())
                Text(workout.name).font(.title2)
                HStack(spacing: 20) {
                    Label("\(workout.rounds) tours", systemImage: "repeat")
                    Label("\(workout.estimatedDuration / 60) min", systemImage: "clock")
                }.foregroundStyle(.secondary)
                Button("Terminer") { onClose() }.buttonStyle(.borderedProminent)
            }.foregroundStyle(.white)
        }
    }
}

private struct WorkoutSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    let workout: WorkoutTemplate
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(workout.name).font(.title.bold())
            if !workout.description.isEmpty { Text(workout.description).foregroundStyle(.secondary) }
            Text("Résumé").font(.headline)
            HStack { Label("\(workout.estimatedDuration / 60) min", systemImage: "clock"); Spacer(); Label("\(workout.rounds) tours", systemImage: "repeat") }
            if workout.preparationSeconds > 0 || workout.roundRestSeconds > 0 || workout.finalRecoverySeconds > 0 {
                Text("Préparation \(workout.preparationSeconds)s • repos entre tours \(workout.roundRestSeconds)s • récupération finale \(workout.finalRecoverySeconds)s")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text("\(workout.steps.count) mouvements").foregroundStyle(.secondary)
            List(workout.steps) { step in Text(stepName(step.exerciseID)) }
            HStack { Spacer(); Button("Annuler") { dismiss() }; Button("Démarrer") { onStart(); dismiss() }.buttonStyle(.borderedProminent) }
        }.padding().frame(width: 420, height: 460)
    }

    private func stepName(_ id: String) -> String { ExerciseLibrary.all.first { $0.id == id }?.name ?? "Mouvement personnalisé" }
}

private struct WorkoutEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var customExercises: [CustomExerciseEntity]
    @State private var name = "Ma séance"
    @State private var description = ""
    @State private var emoji = "💪"
    @State private var rounds = 2
    @State private var preparationSeconds = 0
    @State private var roundRestSeconds = 0
    @State private var finalRecoverySeconds = 0
    @State private var mode = WorkoutMode.interval
    @State private var steps: [WorkoutStep] = []
    @State private var search = ""
    @State private var validationMessage: String?
    private let initialTemplate: WorkoutTemplate?
    let onSave: (WorkoutTemplate) -> Void
    init(template: WorkoutTemplate? = nil, onSave: @escaping (WorkoutTemplate) -> Void) {
        initialTemplate = template
        self.onSave = onSave
        _name = State(initialValue: template?.name ?? "Ma séance")
        _description = State(initialValue: template?.description ?? "")
        _emoji = State(initialValue: template?.emoji ?? "💪")
        _rounds = State(initialValue: template?.rounds ?? 2)
        _preparationSeconds = State(initialValue: template?.preparationSeconds ?? 0)
        _roundRestSeconds = State(initialValue: template?.roundRestSeconds ?? 0)
        _finalRecoverySeconds = State(initialValue: template?.finalRecoverySeconds ?? 0)
        _mode = State(initialValue: template?.mode ?? .interval)
        _steps = State(initialValue: template?.steps ?? [])
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(initialTemplate == nil ? "Nouvelle séance" : "Modifier la séance").font(.title.bold())
            TextField("Nom", text: $name)
            HStack {
                TextField("Emoji", text: $emoji).frame(width: 80)
                TextField("Description (optionnel)", text: $description)
            }
            Stepper("Tours : \(rounds)", value: $rounds, in: 1...20)
            Section("Temps globaux") {
                Stepper("Préparation : \(preparationSeconds) s", value: $preparationSeconds, in: 0...900, step: 5)
                Stepper("Repos entre les tours : \(roundRestSeconds) s", value: $roundRestSeconds, in: 0...900, step: 5)
                Stepper("Récupération finale : \(finalRecoverySeconds) s", value: $finalRecoverySeconds, in: 0...900, step: 5)
            }
            Picker("Mode", selection: $mode) {
                Text("Intervalle").tag(WorkoutMode.interval)
                Text("Répétitions").tag(WorkoutMode.repetitions)
                Text("Libre").tag(WorkoutMode.free)
            }
            Text("Mouvements de la séance").font(.headline)
            if steps.isEmpty {
                Text("Ajoute au moins un mouvement ci-dessous.").foregroundStyle(.secondary)
            } else {
                List {
                    ForEach($steps) { $step in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(exerciseName(step.exerciseID)).font(.headline)
                                Spacer()
                                Button("Dupliquer", systemImage: "plus.square.on.square") { duplicate(step) }
                                    .labelStyle(.iconOnly)
                                Button("Supprimer", systemImage: "trash", role: .destructive) { remove(step) }
                                    .labelStyle(.iconOnly)
                            }
                            if mode == .interval {
                                Stepper("Travail : \(step.workSeconds) s", value: $step.workSeconds, in: 0...900, step: 5)
                                Stepper("Repos : \(step.restSeconds) s", value: $step.restSeconds, in: 0...900, step: 5)
                            } else {
                                Stepper("Répétitions : \(step.workSeconds)", value: $step.workSeconds, in: 1...999)
                            }
                        }
                    }
                    .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
                }
                .frame(minHeight: 120)
            }
            Text("Ajouter un mouvement").font(.headline)
            TextField("Rechercher", text: $search)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(filteredExercises) { exercise in
                        Button { add(exercise) } label: {
                            Label("\(exercise.emoji) \(exercise.name)", systemImage: "plus.circle")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain)
                    }
                }
            }
            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.red)
            }
            HStack { Spacer(); Button("Annuler") { dismiss() }; Button("Sauvegarder") { save() }.buttonStyle(.borderedProminent) }
        }.padding().frame(width: 520, height: 720)
    }
    private func save() {
        let template = WorkoutTemplate(name: name.trimmingCharacters(in: .whitespacesAndNewlines), description: description.trimmingCharacters(in: .whitespacesAndNewlines), emoji: emoji, rounds: rounds, preparationSeconds: preparationSeconds, roundRestSeconds: roundRestSeconds, finalRecoverySeconds: finalRecoverySeconds, steps: steps, mode: mode)
        guard let error = template.validationError else {
            onSave(template); dismiss(); return
        }
        validationMessage = error
    }

    private func add(_ exercise: Exercise) { steps.append(WorkoutStep(exerciseID: exercise.id, workSeconds: mode == .free ? 600 : 40)) }
    private func duplicate(_ step: WorkoutStep) { steps.append(WorkoutStep(exerciseID: step.exerciseID, workSeconds: step.workSeconds, restSeconds: step.restSeconds)) }
    private func remove(_ step: WorkoutStep) { steps.removeAll { $0.id == step.id } }
    private func exerciseName(_ id: String) -> String { allExercises.first { $0.id == id }?.name ?? "Mouvement" }

    private var allExercises: [Exercise] {
        let custom = customExercises.filter { !$0.archived }.compactMap(\.exercise)
        return ExerciseLibrary.all + custom
    }

    private var filteredExercises: [Exercise] {
        allExercises.filter { search.isEmpty || $0.name.localizedStandardContains(search) }
    }
}

private struct WorkoutRunnerView: View {
    @Bindable var store: MoveStore
    let workout: WorkoutTemplate
    var body: some View {
        ZStack { Color.black.opacity(0.9).ignoresSafeArea(); VStack(spacing: 22) {
            Text("Tour \(store.workoutRound)/\(workout.rounds)").foregroundStyle(.secondary)
            ProgressView(value: progress)
                .tint(.white)
                .frame(maxWidth: 360)
            Text(phaseTitle).font(.largeTitle.bold())
            Text(store.workoutState == .working ? "\(MoveCopy.text("runner.next")) : \(nextExerciseName)" : "").foregroundStyle(.secondary)
            Text(workout.mode == .repetitions ? "\(store.secondsRemaining) reps" : "\(store.secondsRemaining)")
                .font(.system(size: 80, weight: .black, design: .rounded)).contentTransition(.numericText())
            HStack {
                Button(store.workoutState == .paused ? MoveCopy.text("runner.resume") : MoveCopy.text("runner.pause")) { store.togglePause() }
                    .keyboardShortcut(.space, modifiers: [])
                    .accessibilityLabel(store.workoutState == .paused ? "Reprendre la séance" : "Mettre la séance en pause")
                if workout.mode != .repetitions {
                    Button("−10 s") { store.subtractTenSeconds() }
                        .accessibilityLabel("Retirer dix secondes")
                    Button("+10 s") { store.addTenSeconds() }
                        .accessibilityLabel("Ajouter dix secondes")
                }
                Button(MoveCopy.text("runner.previous")) { store.previousWorkoutStep() }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button(workout.mode == .repetitions ? MoveCopy.text("runner.done") : MoveCopy.text("runner.nextAction")) { store.advanceWorkout() }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                if workout.mode == .free {
                    Button(MoveCopy.text("runner.addMovement")) { store.recordFreeMovement() }
                        .accessibilityLabel("Enregistrer un mouvement libre")
                }
                if store.workoutState == .resting {
                    Button(MoveCopy.text("runner.skipRest")) { store.advanceWorkout() }
                }
                Button(MoveCopy.text("runner.skip")) { store.skipWorkoutStep() }
                    .accessibilityLabel("Passer cet exercice")
                Button(MoveCopy.text("runner.stop")) { store.cancelWorkout() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .accessibilityLabel("Arrêter la séance")
            }
        }.foregroundStyle(.white) }
    }
    private var exerciseName: String {
        store.exercise(withID: workout.steps[store.workoutStepIndex].exerciseID)?.name ?? "Mouvement"
    }
    private var phaseTitle: String {
        switch store.workoutState {
        case .preparing: MoveCopy.text("runner.preparing")
        case .resting: MoveCopy.text("runner.rest")
        case .roundRest: store.finalRecoveryActive ? MoveCopy.text("runner.finalRecovery") : MoveCopy.text("runner.roundRest")
        default: exerciseName
        }
    }
    private var nextExerciseName: String {
        let next = (store.workoutStepIndex + 1) % workout.steps.count
        return store.exercise(withID: workout.steps[next].exerciseID)?.name ?? "Mouvement"
    }
    private var progress: Double {
        let completed = (store.workoutRound - 1) * workout.steps.count + store.workoutStepIndex
        return Double(completed) / Double(max(1, workout.rounds * workout.steps.count))
    }
}
