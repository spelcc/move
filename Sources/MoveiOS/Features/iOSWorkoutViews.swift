import SwiftUI
import MoveCore

struct iOSWorkoutLibraryView: View {
    @Bindable var store: iOSAppStore
    @State private var preview: WorkoutTemplate?

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
                    ForEach(ExerciseLibrary.quickWorkouts) { workout in
                        Button { preview = workout } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(workout.name).font(.title3.bold())
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
        .fullScreenCover(isPresented: Binding(
            get: { store.workout.activeWorkout != nil || store.workout.completedWorkout != nil },
            set: { if !$0, store.workout.activeWorkout != nil { store.workout.cancel() } }
        )) {
            iOSWorkoutRunnerView(controller: store.workout)
        }
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
