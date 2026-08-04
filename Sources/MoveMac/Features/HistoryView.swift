import SwiftUI
import SwiftData
import MoveCore

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivityEntity.performedAt, order: .reverse) private var activities: [ActivityEntity]
    @State private var editing: ActivityEntity?
    @State private var search = ""

    var body: some View {
        List {
            ForEach(activities.filter { search.isEmpty || $0.exerciseID.localizedStandardContains(search) }) { activity in
                HStack {
                    Text(activity.statusRaw == ActivityStatus.completed.rawValue ? "✓" : "–")
                    VStack(alignment: .leading) { Text(activity.exerciseID); Text(activity.performedAt, style: .date).font(.caption).foregroundStyle(.secondary) }
                    Spacer(); Text("\(activity.amount)").monospacedDigit(); Text(activity.metricRaw).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { editing = activity }
                .contextMenu {
                    Button("Modifier") { editing = activity }
                    Button("Supprimer", role: .destructive) { modelContext.delete(activity); try? modelContext.save() }
                }
            }
        }
        .searchable(text: $search, prompt: "Rechercher dans l’historique")
        .navigationTitle("Historique")
        .overlay { if activities.isEmpty { ContentUnavailableView("Rien pour le moment", systemImage: "clock") } }
        .sheet(item: $editing) { ActivityEditView(activity: $0) }
    }
}

private struct ActivityEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var activity: ActivityEntity
    var body: some View {
        Form {
            Text(activity.exerciseID).font(.headline)
            Stepper("Quantité : \(activity.amount)", value: $activity.amount, in: 0...9999)
            Picker("Statut", selection: $activity.statusRaw) {
                ForEach(ActivityStatus.allCases, id: \.rawValue) { status in Text(status.rawValue).tag(status.rawValue) }
            }
            Button("Terminer") { dismiss() }.buttonStyle(.borderedProminent)
        }.padding().frame(width: 320)
    }
}
