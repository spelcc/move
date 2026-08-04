import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import MoveCore

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivityEntity.performedAt, order: .reverse) private var activities: [ActivityEntity]
    @Query private var customExercises: [CustomExerciseEntity]
    @Query(sort: \.updatedAt, order: .reverse) private var workoutSessions: [WorkoutSessionEntity]
    @State private var editing: ActivityEntity?
    @State private var adding = false
    @State private var exportingJSON = false
    @State private var exportingCSV = false
    @State private var importing = false
    @State private var importError: String?
    @State private var pendingImport: [ActivityRecord] = []
    @State private var importSummary = ""
    @State private var showingImportConfirmation = false
    @State private var search = ""
    @State private var period = HistoryPeriod.all
    @State private var sourceFilter: ActivitySource?
    @State private var statusFilter: ActivityStatus?
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
    @State private var customEnd = Date.now
    @State private var selectedSession: WorkoutSessionEntity?

    private enum HistoryPeriod: String, CaseIterable {
        case today = "Aujourd’hui", week = "Semaine", month = "Mois", custom = "Personnalisée", all = "Tout"
    }

    var body: some View {
        List {
            if !completedSessions.isEmpty {
                Section("Séances terminées") {
                    ForEach(completedSessions) { session in
                        Button { selectedSession = session } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                VStack(alignment: .leading) {
                                    Text(session.workoutName)
                                    Text(session.updatedAt, style: .date)
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("Détails").font(.caption).foregroundStyle(.secondary)
                            }
                        }.buttonStyle(.plain)
                    }
                }
            }
            ForEach(filteredActivities) { activity in
                HStack {
                    Text(activity.statusRaw == ActivityStatus.completed.rawValue ? "✓" : "–")
                    VStack(alignment: .leading) {
                        Text(exerciseName(for: activity.exerciseID))
                        HStack(spacing: 4) {
                            Text(sourceLabel(activity.sourceRaw))
                            Text("•")
                            Text(activity.performedAt, style: .date)
                            Text("à")
                            Text(activity.performedAt, style: .time)
                        }.font(.caption).foregroundStyle(.secondary)
                    }
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
            Picker("Période", selection: $period) { ForEach(HistoryPeriod.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            if period == .custom {
                DatePicker("Du", selection: $customStart, displayedComponents: .date)
                DatePicker("Au", selection: $customEnd, displayedComponents: .date)
            }
            Menu("Filtres", systemImage: "line.3.horizontal.decrease.circle") {
                Menu("Source") {
                    Button("Toutes") { sourceFilter = nil }
                    Button("Rappel") { sourceFilter = .hourly }
                    Button("Séance rapide") { sourceFilter = .quickWorkout }
                    Button("Séance personnalisée") { sourceFilter = .customWorkout }
                    Button("Mouvement libre") { sourceFilter = .freeMovement }
                    Button("Ajout manuel") { sourceFilter = .manual }
                }
                Menu("Statut") {
                    Button("Tous") { statusFilter = nil }
                    Button("Terminées") { statusFilter = .completed }
                    Button("Passées") { statusFilter = .skipped }
                    Button("Reportées") { statusFilter = .snoozed }
                }
            }
            Button("Ajouter", systemImage: "plus") { adding = true }
            Menu("Exporter", systemImage: "square.and.arrow.up") {
                Button("JSON") { exportingJSON = true }
                Button("CSV") { exportingCSV = true }
            }
            Button("Importer", systemImage: "square.and.arrow.down") { importing = true }
        }
        .overlay { if filteredActivities.isEmpty { ContentUnavailableView("Rien pour le moment", systemImage: "clock") } }
        .sheet(item: $editing) { ActivityEditView(activity: $0) }
        .sheet(item: $selectedSession) { WorkoutSessionDetailView(session: $0, customExercises: customExercises) }
        .sheet(isPresented: $adding) { AddActivityView() }
        .fileExporter(isPresented: $exportingJSON, document: ActivityExportDocument(data: jsonData), contentType: .json, defaultFilename: "move-activities.json") { _ in }
        .fileExporter(isPresented: $exportingCSV, document: ActivityExportDocument(data: csvData), contentType: .commaSeparatedText, defaultFilename: "move-activities.csv") { _ in }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            importJSON(result)
        }
        .alert("Import impossible", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) { Button("OK") { importError = nil } } message: { Text(importError ?? "") }
        .alert("Confirmer l’import", isPresented: $showingImportConfirmation) {
            Button("Annuler", role: .cancel) { pendingImport.removeAll() }
            Button("Importer") { applyPendingImport() }
        } message: { Text(importSummary) }
    }

    private var jsonData: Data { (try? DataTransferService.exportJSON(activities.map(\.record))) ?? Data() }
    private var csvData: Data { Data(DataTransferService.exportCSV(activities.map(\.record)).utf8) }

    private var filteredActivities: [ActivityEntity] {
        let calendar = Calendar.current
        let now = Date()
        let start: Date?
        switch period {
        case .today: start = calendar.startOfDay(for: now)
        case .week: start = calendar.date(byAdding: .day, value: -7, to: now)
        case .month: start = calendar.date(byAdding: .month, value: -1, to: now)
        case .custom: start = calendar.startOfDay(for: customStart)
        case .all: start = nil
        }
        let end = period == .custom ? calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEnd)) ?? customEnd : now
        return activities.filter { activity in
            (start == nil || (activity.performedAt >= start! && activity.performedAt < end)) &&
            (search.isEmpty || activity.exerciseID.localizedStandardContains(search)) &&
            (sourceFilter == nil || ActivitySource(rawValue: activity.sourceRaw) == sourceFilter) &&
            (statusFilter == nil || ActivityStatus(rawValue: activity.statusRaw) == statusFilter)
        }
    }

    private var completedSessions: [WorkoutSessionEntity] {
        workoutSessions.filter { $0.stateRaw == WorkoutRunnerState.completed.rawValue }
    }

    private func sourceLabel(_ rawValue: String) -> String {
        switch ActivitySource(rawValue: rawValue) {
        case .hourly: "Rappel"
        case .quickWorkout: "Séance rapide"
        case .customWorkout: "Séance personnalisée"
        case .freeMovement: "Mouvement libre"
        case .manual: "Ajout manuel"
        case .none: "Inconnu"
        }
    }

    private func exerciseName(for id: String) -> String {
        if let builtIn = ExerciseLibrary.all.first(where: { $0.id == id }) { return builtIn.name }
        return customExercises.first(where: { $0.id == id })?.name ?? id
    }

    private func importJSON(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let data = try Data(contentsOf: url)
            let preview = try DataTransferService.previewImport(data, existing: activities.map(\.record))
            pendingImport = preview.records
            importSummary = "\(preview.summary.newRecords) nouvelle(s) activité(s) seront ajoutée(s). \(preview.summary.duplicateRecords) doublon(s) seront ignoré(s)."
            showingImportConfirmation = true
        } catch { importError = error.localizedDescription }
    }

    private func applyPendingImport() {
        pendingImport.forEach { modelContext.insert(ActivityEntity(record: $0)) }
        do { try modelContext.save() } catch { importError = error.localizedDescription }
        pendingImport.removeAll()
    }
}

private struct WorkoutSessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var results: [WorkoutStepResultEntity]
    let session: WorkoutSessionEntity
    let customExercises: [CustomExerciseEntity]

    init(session: WorkoutSessionEntity, customExercises: [CustomExerciseEntity]) {
        self.session = session
        self.customExercises = customExercises
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(session.workoutName).font(.title.bold())
            Text("Terminée le \(session.updatedAt, style: .date) à \(session.updatedAt, style: .time)")
                .foregroundStyle(.secondary)
            HStack {
                Label("\(sessionResults.filter { $0.statusRaw == ActivityStatus.completed.rawValue }.count) terminées", systemImage: "checkmark")
                Label("\(sessionResults.filter { $0.statusRaw == ActivityStatus.skipped.rawValue }.count) passées", systemImage: "forward")
            }
            List(sessionResults) { result in
                HStack {
                    Text(result.statusRaw == ActivityStatus.completed.rawValue ? "✓" : "–")
                    Text(exerciseName(result.exerciseID))
                    Spacer()
                    Text("Tour \(result.round)").foregroundStyle(.secondary)
                }
            }
            HStack { Spacer(); Button("Fermer") { dismiss() }.buttonStyle(.borderedProminent) }
        }
        .padding()
        .frame(width: 480, height: 420)
    }

    private var sessionResults: [WorkoutStepResultEntity] {
        results.filter { $0.sessionID == session.id }.sorted { $0.completedAt < $1.completedAt }
    }

    private func exerciseName(_ id: String) -> String {
        ExerciseLibrary.all.first(where: { $0.id == id })?.name
            ?? customExercises.first(where: { $0.id == id })?.name
            ?? id
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
    @Environment(\.modelContext) private var modelContext
    @Bindable var activity: ActivityEntity
    var body: some View {
        Form {
            Text(activity.exerciseID).font(.headline)
            Stepper("Quantité : \(activity.amount)", value: $activity.amount, in: 0...9999)
            Picker("Statut", selection: $activity.statusRaw) {
                ForEach(ActivityStatus.allCases, id: \.rawValue) { status in Text(status.rawValue).tag(status.rawValue) }
            }
            Button("Terminer") { activity.updatedAt = .now; try? modelContext.save(); dismiss() }.buttonStyle(.borderedProminent)
        }.padding().frame(width: 320)
        .onChange(of: activity.amount) { _, _ in activity.updatedAt = .now }
        .onChange(of: activity.statusRaw) { _, _ in activity.updatedAt = .now }
    }
}
