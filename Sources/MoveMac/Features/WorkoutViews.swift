import SwiftUI
import SwiftData
import MoveCore

struct WorkoutLibraryView: View {
    @Bindable var store: MoveStore
    @Environment(\.modelContext) private var modelContext
    @Query private var customWorkouts: [WorkoutTemplateEntity]
    @State private var showingEditor = false
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Séances").font(.title.bold()); Spacer(); Button("Créer", systemImage: "plus") { showingEditor = true } }
            if let saved = store.resumableWorkout, let workout = ExerciseLibrary.quickWorkouts.first(where: { $0.id == saved.workoutID }) {
                Button("Reprendre \(workout.name)") { store.resume(workout) }
                    .buttonStyle(.borderedProminent)
            }
            LazyVGrid(columns: [.init(.adaptive(minimum: 230))], spacing: 16) {
            ForEach(customWorkouts.filter { !$0.archived }) { entity in
                if let workout = entity.template {
                    workoutCard(workout)
                        .contextMenu { Button("Archiver") { entity.archived = true; entity.updatedAt = .now; try? modelContext.save() } }
                }
            }
            ForEach(ExerciseLibrary.quickWorkouts) { workout in
                Button { store.start(workout) } label: {
                    VStack(alignment: .leading, spacing: 8) { Text(workout.name).font(.title3.bold()); Text("\(workout.estimatedDuration / 60) min • \(workout.rounds) tours").foregroundStyle(.secondary); Text("Démarrer").font(.callout.bold()) }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(.plain)
            }
            }
        }.padding(28) }
        .overlay { if let workout = store.activeWorkout { WorkoutRunnerView(store: store, workout: workout) } }
        .sheet(isPresented: $showingEditor) { WorkoutEditorView { template in
            modelContext.insert(WorkoutTemplateEntity(template: template)); try? modelContext.save()
        } }
    }

    private func workoutCard(_ workout: WorkoutTemplate) -> some View {
        Button { store.start(workout) } label: {
            VStack(alignment: .leading, spacing: 8) { Text(workout.name).font(.title3.bold()); Text("\(workout.estimatedDuration / 60) min • \(workout.rounds) tours").foregroundStyle(.secondary); Text("Démarrer").font(.callout.bold()) }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 20))
        }.buttonStyle(.plain)
    }
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
                                Button("Dupliquer", systemImage: "plus.square.on.square") { duplicate(step.wrappedValue) }
                                    .labelStyle(.iconOnly)
                                Button("Supprimer", systemImage: "trash", role: .destructive) { remove(step.wrappedValue) }
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
            Text(exerciseName).font(.largeTitle.bold())
            Text("\(store.secondsRemaining)").font(.system(size: 80, weight: .black, design: .rounded)).contentTransition(.numericText())
            HStack {
                Button(store.workoutState == .paused ? "Reprendre" : "Pause") { store.togglePause() }
                Button("+10 s") { store.addTenSeconds() }
                Button("Suivant") { store.advanceWorkout() }
                Button("Arrêter") { store.cancelWorkout() }
            }
        }.foregroundStyle(.white) }
    }
    private var exerciseName: String {
        store.exercise(withID: workout.steps[store.workoutStepIndex].exerciseID)?.name ?? "Mouvement"
    }
}
