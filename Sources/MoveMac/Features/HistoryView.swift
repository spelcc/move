import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import MoveCore

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivityEntity.performedAt, order: .reverse) private var activities: [ActivityEntity]
    @Query private var customExercises: [CustomExerciseEntity]
    @Query(sort: \WorkoutSessionEntity.updatedAt, order: .reverse) private var workoutSessions: [WorkoutSessionEntity]
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
    @State private var categoryFilter: ExerciseCategory?
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
                    Button(MoveCopy.text("common.edit")) { editing = activity }
                    Button(MoveCopy.text("common.delete"), role: .destructive) { modelContext.delete(activity); try? modelContext.save() }
                }
            }
        }
        .searchable(text: $search, prompt: MoveCopy.text("history.search"))
        .navigationTitle(MoveCopy.text("nav.history"))
        .toolbar {
            Picker(MoveCopy.text("history.period"), selection: $period) { ForEach(HistoryPeriod.allCases, id: \.self) { Text(periodLabel($0)).tag($0) } }
            if period == .custom {
                DatePicker(MoveCopy.text("history.from"), selection: $customStart, displayedComponents: .date)
                DatePicker(MoveCopy.text("history.to"), selection: $customEnd, displayedComponents: .date)
            }
            Menu(MoveCopy.text("history.filters"), systemImage: "line.3.horizontal.decrease.circle") {
                Menu(MoveCopy.text("history.category")) {
                    Button(MoveCopy.text("history.all")) { categoryFilter = nil }
                    ForEach(ExerciseCategory.allCases, id: \.self) { category in
                        Button(category.rawValue.capitalized) { categoryFilter = category }
                    }
                }
                Menu(MoveCopy.text("history.source")) {
                    Button(MoveCopy.text("history.all")) { sourceFilter = nil }
                    Button(MoveCopy.text("source.reminder")) { sourceFilter = .hourly }
                    Button(MoveCopy.text("source.quick")) { sourceFilter = .quickWorkout }
                    Button(MoveCopy.text("source.custom")) { sourceFilter = .customWorkout }
                    Button(MoveCopy.text("source.free")) { sourceFilter = .freeMovement }
                    Button(MoveCopy.text("source.manual")) { sourceFilter = .manual }
                }
                Menu(MoveCopy.text("history.status")) {
                    Button(MoveCopy.text("history.all")) { statusFilter = nil }
                    Button(MoveCopy.text("status.completed")) { statusFilter = .completed }
                    Button(MoveCopy.text("status.skipped")) { statusFilter = .skipped }
                    Button(MoveCopy.text("status.snoozed")) { statusFilter = .snoozed }
                }
            }
            Button(MoveCopy.text("history.add"), systemImage: "plus") { adding = true }
            Menu(MoveCopy.text("history.export"), systemImage: "square.and.arrow.up") {
                Button(MoveCopy.text("history.json")) { exportingJSON = true }
                Button(MoveCopy.text("history.csv")) { exportingCSV = true }
            }
            Button(MoveCopy.text("history.import"), systemImage: "square.and.arrow.down") { importing = true }
        }
        .overlay { if filteredActivities.isEmpty { ContentUnavailableView(MoveCopy.text("empty.history.title"), systemImage: "clock", description: Text(MoveCopy.text("empty.history.message"))) } }
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
            (categoryFilter == nil || category(for: activity.exerciseID) == categoryFilter) &&
            (sourceFilter == nil || ActivitySource(rawValue: activity.sourceRaw) == sourceFilter) &&
            (statusFilter == nil || ActivityStatus(rawValue: activity.statusRaw) == statusFilter)
        }
    }

    private var completedSessions: [WorkoutSessionEntity] {
        workoutSessions.filter { $0.stateRaw == WorkoutRunnerState.completed.rawValue }
    }

    private func sourceLabel(_ rawValue: String) -> String {
        switch ActivitySource(rawValue: rawValue) {
        case .hourly: MoveCopy.text("source.reminder")
        case .quickWorkout: MoveCopy.text("source.quick")
        case .customWorkout: MoveCopy.text("source.custom")
        case .freeMovement: MoveCopy.text("source.free")
        case .manual: MoveCopy.text("source.manual")
        case .none: MoveCopy.text("source.unknown")
        }
    }

    private func periodLabel(_ period: HistoryPeriod) -> String {
        switch period {
        case .today: MoveCopy.text("period.today")
        case .week: MoveCopy.text("period.week")
        case .month: MoveCopy.text("period.month")
        case .custom: MoveCopy.text("period.custom")
        case .all: MoveCopy.text("period.all")
        }
    }

    private func exerciseName(for id: String) -> String {
        if let builtIn = ExerciseLibrary.all.first(where: { $0.id == id }) { return builtIn.name }
        return customExercises.first(where: { $0.id == id })?.name ?? id
    }

    private func category(for id: String) -> ExerciseCategory? {
        if let builtIn = ExerciseLibrary.all.first(where: { $0.id == id }) { return builtIn.category }
        return customExercises.first(where: { $0.id == id }).flatMap { ExerciseCategory(rawValue: $0.categoryRaw) }
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
            Text(String(format: MoveCopy.text("history.completedAt"), session.updatedAt.formatted(date: .long, time: .shortened)))
                .foregroundStyle(.secondary)
            HStack {
                Label(String(format: MoveCopy.text("history.plannedMinutes"), session.plannedDurationSeconds / 60), systemImage: "calendar")
                Label(String(format: MoveCopy.text("history.actualMinutes"), max(0, Int(session.updatedAt.timeIntervalSince(session.startedAt)) / 60)), systemImage: "stopwatch")
            }
            HStack {
                Label(String(format: MoveCopy.text("history.completedCount"), sessionResults.filter { $0.statusRaw == ActivityStatus.completed.rawValue }.count), systemImage: "checkmark")
                Label(String(format: MoveCopy.text("history.skippedCount"), sessionResults.filter { $0.statusRaw == ActivityStatus.skipped.rawValue }.count), systemImage: "forward")
            }
            List(sessionResults) { result in
                HStack {
                    Text(result.statusRaw == ActivityStatus.completed.rawValue ? "✓" : "–")
                    Text(exerciseName(result.exerciseID))
                    Spacer()
                    Text(String(format: MoveCopy.text("history.round"), result.round)).foregroundStyle(.secondary)
                }
            }
            HStack { Spacer(); Button(MoveCopy.text("common.close")) { dismiss() }.buttonStyle(.borderedProminent) }
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
            Picker(MoveCopy.text("history.movement"), selection: $exerciseID) { ForEach(allExercises) { Text($0.name).tag($0.id) } }
            Stepper(String(format: MoveCopy.text("history.amount"), amount), value: $amount, in: 0...9999)
            Picker(MoveCopy.text("history.status"), selection: $status) { ForEach(ActivityStatus.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
            HStack { Spacer(); Button(MoveCopy.text("common.cancel")) { dismiss() }; Button(MoveCopy.text("history.add")) { save() }.buttonStyle(.borderedProminent) }
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
            Stepper(String(format: MoveCopy.text("history.amount"), activity.amount), value: $activity.amount, in: 0...9999)
            Picker(MoveCopy.text("history.status"), selection: $activity.statusRaw) {
                ForEach(ActivityStatus.allCases, id: \.rawValue) { status in Text(status.rawValue).tag(status.rawValue) }
            }
            Button(MoveCopy.text("common.done")) { activity.updatedAt = .now; try? modelContext.save(); dismiss() }.buttonStyle(.borderedProminent)
        }.padding().frame(width: 320)
        .onChange(of: activity.amount) { _, _ in activity.updatedAt = .now }
        .onChange(of: activity.statusRaw) { _, _ in activity.updatedAt = .now }
    }
}
