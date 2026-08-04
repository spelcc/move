import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import MoveCore

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivityEntity.performedAt, order: .reverse) private var activities: [ActivityEntity]
    @State private var editing: ActivityEntity?
    @State private var adding = false
    @State private var exportingJSON = false
    @State private var exportingCSV = false
    @State private var importing = false
    @State private var importError: String?
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
        .toolbar {
            Button("Ajouter", systemImage: "plus") { adding = true }
            Menu("Exporter", systemImage: "square.and.arrow.up") {
                Button("JSON") { exportingJSON = true }
                Button("CSV") { exportingCSV = true }
            }
            Button("Importer", systemImage: "square.and.arrow.down") { importing = true }
        }
        .overlay { if activities.isEmpty { ContentUnavailableView("Rien pour le moment", systemImage: "clock") } }
        .sheet(item: $editing) { ActivityEditView(activity: $0) }
        .sheet(isPresented: $adding) { AddActivityView() }
        .fileExporter(isPresented: $exportingJSON, document: ActivityExportDocument(data: jsonData), contentType: .json, defaultFilename: "move-activities.json") { _ in }
        .fileExporter(isPresented: $exportingCSV, document: ActivityExportDocument(data: csvData), contentType: .commaSeparatedText, defaultFilename: "move-activities.csv") { _ in }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            importJSON(result)
        }
        .alert("Import impossible", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) { Button("OK") { importError = nil } } message: { Text(importError ?? "") }
    }

    private var jsonData: Data { (try? DataTransferService.exportJSON(activities.map(\.record))) ?? Data() }
    private var csvData: Data { Data(DataTransferService.exportCSV(activities.map(\.record)).utf8) }

    private func importJSON(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let data = try Data(contentsOf: url)
            let records = try DataTransferService.importJSON(data, existing: activities.map(\.record))
            records.forEach { modelContext.insert(ActivityEntity(record: $0)) }
            try modelContext.save()
        } catch { importError = error.localizedDescription }
    }
}

struct ActivityExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data
    init(data: Data = Data()) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private struct AddActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var customExercises: [CustomExerciseEntity]
    @State private var exerciseID = ExerciseLibrary.all.first?.id ?? ""
    @State private var amount = 10
    @State private var status = ActivityStatus.completed
    var body: some View {
        Form {
            Picker("Mouvement", selection: $exerciseID) { ForEach(allExercises) { Text($0.name).tag($0.id) } }
            Stepper("Quantité : \(amount)", value: $amount, in: 0...9999)
            Picker("Statut", selection: $status) { ForEach(ActivityStatus.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            HStack { Spacer(); Button("Annuler") { dismiss() }; Button("Ajouter") { save() }.buttonStyle(.borderedProminent) }
        }.padding().frame(width: 400)
    }
    private func save() {
        let exercise = allExercises.first { $0.id == exerciseID } ?? ExerciseLibrary.all[0]
        modelContext.insert(ActivityEntity(record: .init(exerciseID: exercise.id, amount: amount, metric: exercise.metric, status: status, source: .manual)))
        try? modelContext.save(); dismiss()
    }

    private var allExercises: [Exercise] {
        ExerciseLibrary.all + customExercises.filter { !$0.archived }.compactMap(\.exercise)
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
        .onChange(of: activity.amount) { _, _ in activity.updatedAt = .now }
        .onChange(of: activity.statusRaw) { _, _ in activity.updatedAt = .now }
    }
}
