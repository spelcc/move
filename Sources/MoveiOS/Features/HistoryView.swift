import SwiftUI
import SwiftData
import MoveCore
import MoveShared

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivityEntity.performedAt, order: .reverse) private var activities: [ActivityEntity]
    @Query private var customExercises: [CustomExerciseEntity]
    @State private var editingActivity: ActivityEntity?
    @State private var pendingDeletion: ActivityEntity?

    var body: some View {
        NavigationStack {
            List {
                if activities.isEmpty {
                    ContentUnavailableView(
                        "Aucune activité",
                        systemImage: "clock",
                        description: Text("Tes mouvements réalisés apparaîtront ici.")
                    )
                }
                ForEach(activities) { activity in
                    let exercise = exercise(for: activity.exerciseID)
                    HStack {
                        Text(exercise?.emoji ?? "💪")
                        VStack(alignment: .leading) {
                            Text(exercise?.name ?? activity.exerciseID)
                            Text(activity.performedAt, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            if activity.statusRaw == ActivityStatus.completed.rawValue {
                                Text(amountLabel(activity))
                                    .font(.headline)
                                    .monospacedDigit()
                                Text("Terminé")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                Text(statusLabel(activity.statusRaw))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editingActivity = activity }
                    .swipeActions {
                        Button(role: .destructive) {
                            pendingDeletion = activity
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                        Button {
                            editingActivity = activity
                        } label: {
                            Label("Modifier", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle("Historique")
            .sheet(item: $editingActivity) { activity in
                iOSActivityAmountEditView(
                    activity: activity,
                    exercise: exercise(for: activity.exerciseID)
                )
            }
            .alert("Supprimer ce mouvement ?", isPresented: deletionAlertPresented) {
                Button("Supprimer", role: .destructive) { deletePendingActivity() }
                Button("Annuler", role: .cancel) { pendingDeletion = nil }
            } message: {
                Text("Cette action supprimera définitivement cette entrée de l’historique.")
            }
        }
    }

    private var deletionAlertPresented: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }

    private func exercise(for id: String) -> Exercise? {
        ExerciseLibrary.all.first { $0.id == id }
            ?? customExercises.first { $0.id == id }?.exercise
    }

    private func statusLabel(_ raw: String) -> String {
        switch ActivityStatus(rawValue: raw) {
        case .skipped: "Ignoré"
        case .snoozed: "Reporté"
        case .replaced: "Remplacé"
        case .proposed: "Proposé"
        default: raw.capitalized
        }
    }

    private func amountLabel(_ activity: ActivityEntity) -> String {
        switch ExerciseMetric(rawValue: activity.metricRaw) {
        case .repetitions: "\(activity.amount) rép."
        case .seconds: "\(activity.amount) s"
        case .minutes: "\(activity.amount) min"
        default: "\(activity.amount)"
        }
    }

    private func deletePendingActivity() {
        guard let activity = pendingDeletion else { return }
        modelContext.delete(activity)
        try? modelContext.save()
        pendingDeletion = nil
    }
}
