import SwiftUI
import MoveCore

struct HistoryStore {
    static let key = "move.activityRecords"
    static func load() -> [ActivityRecord] { guard let data = UserDefaults.standard.data(forKey: key), let records = try? JSONDecoder().decode([ActivityRecord].self, from: data) else { return [] }; return records }
    static func save(_ records: [ActivityRecord]) { if let data = try? JSONEncoder().encode(records) { UserDefaults.standard.set(data, forKey: key) } }
    static func append(_ record: ActivityRecord) { save((load() + [record]).sorted { $0.performedAt > $1.performedAt }) }
}

struct HistoryView: View {
    @State private var records = HistoryStore.load()
    var body: some View {
        NavigationStack {
            List {
                if records.isEmpty { ContentUnavailableView("Aucune activité", systemImage: "clock", description: Text("Tes mouvements réalisés apparaîtront ici.")) }
                ForEach(records) { record in
                    let exercise = ExerciseLibrary.all.first { $0.id == record.exerciseID }
                    HStack { Text(exercise?.emoji ?? "💪"); VStack(alignment: .leading) { Text(exercise?.name ?? record.exerciseID); Text(record.performedAt, style: .date).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text(record.status == .completed ? "✓" : record.status.rawValue.capitalized).foregroundStyle(record.status == .completed ? .green : .secondary) }
                }
            }.navigationTitle("Historique").onAppear { records = HistoryStore.load() }
        }
    }
}
