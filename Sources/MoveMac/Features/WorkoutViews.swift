import SwiftUI
import MoveCore

struct WorkoutLibraryView: View {
    @Bindable var store: MoveStore
    var body: some View {
        ScrollView { LazyVGrid(columns: [.init(.adaptive(minimum: 230))], spacing: 16) {
            ForEach(ExerciseLibrary.quickWorkouts) { workout in
                Button { store.start(workout) } label: {
                    VStack(alignment: .leading, spacing: 8) { Text(workout.name).font(.title3.bold()); Text("\(workout.estimatedDuration / 60) min • \(workout.rounds) tours").foregroundStyle(.secondary); Text("Démarrer").font(.callout.bold()) }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(.plain)
            }
        }.padding(28) }
        .overlay { if let workout = store.activeWorkout { WorkoutRunnerView(store: store, workout: workout) } }
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
                Button("Arrêter") { store.workoutState = .cancelled; store.activeWorkout = nil }
            }
        }.foregroundStyle(.white) }
    }
    private var exerciseName: String { ExerciseLibrary.builtIn.first(where: { $0.id == workout.steps[store.workoutStepIndex].exerciseID })?.name ?? "Mouvement" }
}
