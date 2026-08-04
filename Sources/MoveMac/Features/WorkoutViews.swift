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
    @State private var name = "Ma séance"
    @State private var rounds = 2
    @State private var selected = Set<String>()
    let onSave: (WorkoutTemplate) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nouvelle séance").font(.title.bold())
            TextField("Nom", text: $name)
            Stepper("Tours : \(rounds)", value: $rounds, in: 1...20)
            Text("Mouvements").font(.headline)
            List(ExerciseLibrary.builtIn.prefix(12)) { exercise in
                Toggle(isOn: Binding(get: { selected.contains(exercise.id) }, set: { if $0 { selected.insert(exercise.id) } else { selected.remove(exercise.id) } })) { Text("\(exercise.emoji) \(exercise.name)") }
            }
            HStack { Spacer(); Button("Annuler") { dismiss() }; Button("Sauvegarder") { save() }.buttonStyle(.borderedProminent).disabled(selected.isEmpty) }
        }.padding().frame(width: 420, height: 560)
    }
    private func save() {
        let steps = ExerciseLibrary.builtIn.filter { selected.contains($0.id) }.map { WorkoutStep(exerciseID: $0.id) }
        onSave(WorkoutTemplate(name: name, rounds: rounds, steps: steps)); dismiss()
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
    private var exerciseName: String { ExerciseLibrary.builtIn.first(where: { $0.id == workout.steps[store.workoutStepIndex].exerciseID })?.name ?? "Mouvement" }
}
