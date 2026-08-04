import SwiftUI
import SwiftData
import MoveCore

struct WorkoutLibraryView: View {
    @Bindable var store: MoveStore
    @Environment(\.modelContext) private var modelContext
    @Query private var customWorkouts: [WorkoutTemplateEntity]
    @State private var showingEditor = false
    @State private var previewing: WorkoutTemplate?
    @State private var renaming: WorkoutTemplateEntity?
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Séances").font(.title.bold()); Spacer(); Button("Créer", systemImage: "plus") { showingEditor = true } }
            if let saved = store.resumableWorkout, let workout = resumableWorkout(saved) {
                Button("Reprendre \(workout.name)") { store.resume(workout) }
                    .buttonStyle(.borderedProminent)
            }
            LazyVGrid(columns: [.init(.adaptive(minimum: 230))], spacing: 16) {
            ForEach(customWorkouts.filter { !$0.archived }) { entity in
                if let workout = entity.template {
                    workoutCard(workout)
                        .contextMenu {
                            Button("Dupliquer") { duplicate(entity) }
                            Button("Renommer") { renaming = entity }
                            Button("Archiver") { archive(entity) }
                            Button("Supprimer", role: .destructive) { delete(entity) }
                        }
                }
            }
            ForEach(ExerciseLibrary.quickWorkouts) { workout in
                Button { previewing = workout } label: {
                    VStack(alignment: .leading, spacing: 8) { Text(workout.name).font(.title3.bold()); Text("\(workout.estimatedDuration / 60) min • \(workout.rounds) tours").foregroundStyle(.secondary); Text("Démarrer").font(.callout.bold()) }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 20))
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
        .sheet(item: $previewing) { workout in
            WorkoutSummaryView(workout: workout) { store.start(workout); previewing = nil }
        }
        .sheet(item: $renaming) { entity in
            WorkoutRenameView(entity: entity)
        }
    }

    private func workoutCard(_ workout: WorkoutTemplate) -> some View {
        Button { previewing = workout } label: {
            VStack(alignment: .leading, spacing: 8) { Text(workout.name).font(.title3.bold()); Text("\(workout.estimatedDuration / 60) min • \(workout.rounds) tours").foregroundStyle(.secondary); Text("Démarrer").font(.callout.bold()) }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 20))
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
        let copy = WorkoutTemplate(id: UUID(), name: "\(template.name) (copie)", rounds: template.rounds, steps: template.steps, mode: template.mode)
        modelContext.insert(WorkoutTemplateEntity(template: copy))
        try? modelContext.save()
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
            Text("Résumé").font(.headline)
            HStack { Label("\(workout.estimatedDuration / 60) min", systemImage: "clock"); Spacer(); Label("\(workout.rounds) tours", systemImage: "repeat") }
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
    @State private var rounds = 2
    @State private var mode = WorkoutMode.interval
    @State private var steps: [WorkoutStep] = []
    @State private var search = ""
    let onSave: (WorkoutTemplate) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nouvelle séance").font(.title.bold())
            TextField("Nom", text: $name)
            Stepper("Tours : \(rounds)", value: $rounds, in: 1...20)
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
            HStack { Spacer(); Button("Annuler") { dismiss() }; Button("Sauvegarder") { save() }.buttonStyle(.borderedProminent).disabled(steps.isEmpty) }
        }.padding().frame(width: 520, height: 720)
    }
    private func save() {
        onSave(WorkoutTemplate(name: name, rounds: rounds, steps: steps, mode: mode)); dismiss()
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
            Text(store.workoutState == .resting ? "Repos" : exerciseName).font(.largeTitle.bold())
            Text(store.workoutState == .resting ? "Prochain : \(nextExerciseName)" : "Suivant : \(nextExerciseName)").foregroundStyle(.secondary)
            Text("\(store.secondsRemaining)").font(.system(size: 80, weight: .black, design: .rounded)).contentTransition(.numericText())
            HStack {
                Button(store.workoutState == .paused ? "Reprendre" : "Pause") { store.togglePause() }
                    .keyboardShortcut(.space, modifiers: [])
                    .accessibilityLabel(store.workoutState == .paused ? "Reprendre la séance" : "Mettre la séance en pause")
                Button("−10 s") { store.subtractTenSeconds() }
                    .accessibilityLabel("Retirer dix secondes")
                Button("+10 s") { store.addTenSeconds() }
                    .accessibilityLabel("Ajouter dix secondes")
                Button("Précédent") { store.previousWorkoutStep() }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button("Suivant") { store.advanceWorkout() }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                if store.workoutState == .resting {
                    Button("Passer le repos") { store.advanceWorkout() }
                }
                Button("Passer") { store.skipWorkoutStep() }
                    .accessibilityLabel("Passer cet exercice")
                Button("Arrêter") { store.cancelWorkout() }
                    .keyboardShortcut(.escape, modifiers: [])
                    .accessibilityLabel("Arrêter la séance")
            }
        }.foregroundStyle(.white) }
    }
    private var exerciseName: String {
        store.exercise(withID: workout.steps[store.workoutStepIndex].exerciseID)?.name ?? "Mouvement"
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
