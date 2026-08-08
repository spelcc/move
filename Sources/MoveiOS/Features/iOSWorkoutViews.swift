import SwiftUI
import SwiftData
import MoveCore
import MoveShared

struct iOSWorkoutLibraryView: View {
    @Bindable var store: iOSAppStore
    @Environment(\.modelContext) private var modelContext
    @Query private var customWorkouts: [WorkoutTemplateEntity]
    @State private var preview: WorkoutTemplate?
    @State private var showingEditor = false
    @State private var editingWorkout: WorkoutTemplateEntity?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 14) {
                    if let resumable = store.workout.resumableWorkout {
                        Button { store.workout.resume() } label: {
                            Label("Reprendre \(resumable.name)", systemImage: "play.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(.plain)
                    }
                    HStack {
                        Text("Mes workouts").font(.title2.bold())
                        Spacer()
                        Button("Nouveau", systemImage: "plus") { showingEditor = true }
                    }
                    ForEach(customWorkouts.filter { !$0.archived }) { entity in
                        if let workout = entity.template {
                            workoutCard(workout)
                                .contextMenu {
                                    Button("Modifier") { editingWorkout = entity }
                                    Button("Dupliquer") { duplicate(entity) }
                                    Button("Supprimer", role: .destructive) { delete(entity) }
                                }
                        }
                    }
                    if customWorkouts.filter({ !$0.archived }).isEmpty {
                        Text("Crée ton premier workout personnalisé.")
                            .foregroundStyle(.secondary)
                    }
                    Text("Workouts intégrés").font(.title2.bold())
                    ForEach(ExerciseLibrary.quickWorkouts) { workout in
                        workoutCard(workout)
                    }
                }
                .padding()
            }
            .navigationTitle("Workouts")
        }
        .sheet(item: $preview) { workout in
            iOSWorkoutPreviewView(workout: workout) {
                store.workout.start(workout)
                preview = nil
            }
        }
        .sheet(isPresented: $showingEditor) {
            iOSWorkoutEditorView { template in
                modelContext.insert(WorkoutTemplateEntity(template: template))
                try? modelContext.save()
            }
        }
        .sheet(item: $editingWorkout) { entity in
            iOSWorkoutEditorView(template: entity.template) { template in
                entity.name = template.name
                entity.templateData = (try? JSONEncoder().encode(template)) ?? entity.templateData
                entity.updatedAt = .now
                try? modelContext.save()
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { store.workout.activeWorkout != nil || store.workout.completedWorkout != nil },
            set: { if !$0, store.workout.activeWorkout != nil { store.workout.cancel() } }
        )) {
            iOSWorkoutRunnerView(controller: store.workout)
        }
    }

    private func workoutCard(_ workout: WorkoutTemplate) -> some View {
        Button { preview = workout } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(workout.emoji)  \(workout.name)").font(.title3.bold())
                Text("\(max(1, workout.estimatedDuration / 60)) min • \(workout.rounds) tour\(workout.rounds > 1 ? "s" : "")")
                    .foregroundStyle(.secondary)
                Text("Voir la séance").font(.callout.bold())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private func duplicate(_ entity: WorkoutTemplateEntity) {
        guard let template = entity.template else { return }
        let copy = WorkoutTemplate(
            name: "\(template.name) copie", description: template.description, emoji: template.emoji,
            rounds: template.rounds, preparationSeconds: template.preparationSeconds,
            roundRestSeconds: template.roundRestSeconds, finalRecoverySeconds: template.finalRecoverySeconds,
            steps: template.steps, mode: template.mode
        )
        modelContext.insert(WorkoutTemplateEntity(template: copy))
        try? modelContext.save()
    }

    private func delete(_ entity: WorkoutTemplateEntity) {
        modelContext.delete(entity)
        try? modelContext.save()
    }
}

private struct iOSWorkoutEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var customExercises: [CustomExerciseEntity]
    @State private var name: String
    @State private var description: String
    @State private var emoji: String
    @State private var rounds: Int
    @State private var preparationSeconds: Int
    @State private var roundRestSeconds: Int
    @State private var finalRecoverySeconds: Int
    @State private var mode: WorkoutMode
    @State private var steps: [WorkoutStep]
    @State private var search = ""
    @State private var error: String?
    let onSave: (WorkoutTemplate) -> Void

    init(template: WorkoutTemplate? = nil, onSave: @escaping (WorkoutTemplate) -> Void) {
        _name = State(initialValue: template?.name ?? "Mon workout")
        _description = State(initialValue: template?.description ?? "")
        _emoji = State(initialValue: template?.emoji ?? "💪")
        _rounds = State(initialValue: template?.rounds ?? 2)
        _preparationSeconds = State(initialValue: template?.preparationSeconds ?? 0)
        _roundRestSeconds = State(initialValue: template?.roundRestSeconds ?? 0)
        _finalRecoverySeconds = State(initialValue: template?.finalRecoverySeconds ?? 0)
        _mode = State(initialValue: template?.mode ?? .interval)
        _steps = State(initialValue: template?.steps ?? [])
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Workout") {
                    TextField("Nom", text: $name)
                    TextField("Emoji", text: $emoji)
                    TextField("Description", text: $description, axis: .vertical)
                    Stepper("Tours : \(rounds)", value: $rounds, in: 1...20)
                    Picker("Mode", selection: $mode) {
                        Text("Intervalle").tag(WorkoutMode.interval)
                        Text("Répétitions").tag(WorkoutMode.repetitions)
                        Text("Libre").tag(WorkoutMode.free)
                    }
                }
                Section("Temps globaux") {
                    Stepper("Préparation : \(preparationSeconds) s", value: $preparationSeconds, in: 0...900, step: 5)
                    Stepper("Repos entre les tours : \(roundRestSeconds) s", value: $roundRestSeconds, in: 0...900, step: 5)
                    Stepper("Récupération finale : \(finalRecoverySeconds) s", value: $finalRecoverySeconds, in: 0...900, step: 5)
                }
                Section("Mouvements") {
                    ForEach($steps) { $step in
                        VStack(alignment: .leading) {
                            HStack {
                                Text(exerciseName(step.exerciseID)).font(.headline)
                                Spacer()
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
                    TextField("Rechercher un mouvement", text: $search)
                    ForEach(filteredExercises, id: \.id) { exercise in
                        Button { add(exercise) } label: {
                            Label("\(exercise.emoji)  \(exercise.name)", systemImage: "plus.circle")
                        }
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }
            .navigationTitle("Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var allExercises: [Exercise] {
        ExerciseLibrary.all + customExercises.filter { !$0.archived }.compactMap(\.exercise)
    }

    private var filteredExercises: [Exercise] {
        allExercises.filter { search.isEmpty || $0.name.localizedStandardContains(search) }
    }

    private func exerciseName(_ id: String) -> String {
        allExercises.first { $0.id == id }?.name ?? id
    }

    private func add(_ exercise: Exercise) {
        steps.append(WorkoutStep(exerciseID: exercise.id, workSeconds: mode == .free ? 600 : 40))
    }

    private func remove(_ step: WorkoutStep) {
        steps.removeAll { $0.id == step.id }
    }

    private func save() {
        let template = WorkoutTemplate(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines), description: description,
            emoji: emoji.isEmpty ? "💪" : emoji, rounds: rounds,
            preparationSeconds: preparationSeconds, roundRestSeconds: roundRestSeconds,
            finalRecoverySeconds: finalRecoverySeconds, steps: steps, mode: mode
        )
        guard let validationError = template.validationError else {
            onSave(template)
            dismiss()
            return
        }
        error = validationError
    }
}

private struct iOSWorkoutPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let workout: WorkoutTemplate
    let onStart: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("\(max(1, workout.estimatedDuration / 60)) min", systemImage: "clock")
                    Label("\(workout.rounds) tour\(workout.rounds > 1 ? "s" : "")", systemImage: "repeat")
                }
                Section("Mouvements") {
                    ForEach(Array(workout.steps.enumerated()), id: \.element.id) { index, step in
                        HStack {
                            Text("\(index + 1)").foregroundStyle(.secondary)
                            Text(ExerciseLibrary.all.first { $0.id == step.exerciseID }?.name ?? step.exerciseID)
                            Spacer()
                            Text(workout.mode == .repetitions ? "\(step.workSeconds) reps" : "\(step.workSeconds) s")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(workout.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Démarrer") { onStart() }.buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

private struct iOSWorkoutRunnerView: View {
    @Bindable var controller: iOSWorkoutController

    var body: some View {
        NavigationStack {
            Group {
                if let completed = controller.completedWorkout {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.green)
                        Text("Séance terminée").font(.largeTitle.bold())
                        Text(completed.name).font(.title2)
                        Button("Terminer") { controller.dismissCompletion() }
                            .buttonStyle(.borderedProminent)
                    }
                } else if let workout = controller.activeWorkout {
                    VStack(spacing: 22) {
                        Text(phaseTitle).font(.headline).foregroundStyle(.secondary)
                        Text(controller.currentExercise?.emoji ?? "💪").font(.system(size: 64))
                        Text(controller.currentExercise?.name ?? "Mouvement").font(.title.bold())
                        Text(counterText)
                            .font(.system(size: 58, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("Tour \(min(controller.round, workout.rounds))/\(workout.rounds) • mouvement \(controller.stepIndex + 1)/\(workout.steps.count)")
                            .foregroundStyle(.secondary)
                        controls(for: workout)
                    }
                    .padding()
                    .navigationTitle(workout.name)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Quitter", role: .destructive) { controller.cancel() }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .interactiveDismissDisabled(controller.activeWorkout != nil)
    }

    @ViewBuilder private func controls(for workout: WorkoutTemplate) -> some View {
        if workout.mode == .repetitions, controller.state == .working {
            Button("Étape terminée") { controller.completeRepetitionStep() }
                .buttonStyle(.borderedProminent)
        } else {
            HStack {
                Button("− 10 s") { controller.subtractTenSeconds() }
                Button("+ 10 s") { controller.addTenSeconds() }
            }
        }
        HStack {
            Button(controller.state == .paused ? "Reprendre" : "Pause") { controller.togglePause() }
                .buttonStyle(.borderedProminent)
            Button("Ignorer") { controller.skipStep() }.buttonStyle(.bordered)
        }
    }

    private var phaseTitle: String {
        switch controller.state {
        case .preparing: "Préparation"
        case .working: "Travail"
        case .resting: "Repos"
        case .roundRest: controller.finalRecoveryActive ? "Récupération" : "Repos entre les tours"
        case .paused: "En pause"
        case .completed: "Terminé"
        case .cancelled: "Annulé"
        }
    }

    private var counterText: String {
        if controller.activeWorkout?.mode == .repetitions, controller.state == .working {
            return "\(controller.secondsRemaining) reps"
        }
        return String(format: "%02d:%02d", controller.secondsRemaining / 60, controller.secondsRemaining % 60)
    }
}
