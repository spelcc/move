import SwiftUI
import SwiftData
import MoveCore

struct DashboardView: View {
    @Query(sort: \ActivityEntity.performedAt, order: .reverse) private var activities: [ActivityEntity]
    @Bindable var store: MoveStore
    var body: some View {
        NavigationSplitView {
            List(selection: $store.selectedTab) {
                Label(MoveCopy.text("nav.today"), systemImage: "figure.run").tag("Aujourd’hui")
                Label(MoveCopy.text("nav.history"), systemImage: "clock").tag("Historique")
                Label(MoveCopy.text("nav.progress"), systemImage: "chart.bar").tag("Progression")
                Label(MoveCopy.text("nav.workouts"), systemImage: "timer").tag("Séances")
                Label(MoveCopy.text("nav.movements"), systemImage: "list.bullet").tag("Mouvements")
                Label(MoveCopy.text("nav.settings"), systemImage: "gear").tag("Réglages")
            }.navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            switch store.selectedTab {
            case "Historique": HistoryView()
            case "Progression": MoveProgressView()
            case "Séances": WorkoutLibraryView(store: store)
            case "Mouvements": MovementSettingsView(store: store)
            case "Réglages": SettingsView(store: store)
            default: TodayView(activities: activities)
            }
        }
        .frame(minWidth: 780, minHeight: 520)
    }
}

private struct TodayView: View {
    let activities: [ActivityEntity]
    var body: some View {
        let today = Calendar.current.startOfDay(for: .now)
        let todaysActivities = activities.filter { $0.performedAt >= today }
        let stats = StatisticsService.calculate(todaysActivities.map(\.record))
        ScrollView { VStack(alignment: .leading, spacing: 20) {
            Text(MoveCopy.text("nav.today")).font(.largeTitle.bold())
            HStack { StatCard(value: "\(stats.completedCount)", label: MoveCopy.text("stats.movements")); StatCard(value: "\(stats.totalRepetitions)", label: MoveCopy.text("stats.repetitions")); StatCard(value: "\(stats.activeSeconds / 60) min", label: MoveCopy.text("stats.activeMinutes")) }
            Text(MoveCopy.text("nav.history")).font(.title2.bold())
            if todaysActivities.isEmpty {
                ContentUnavailableView(MoveCopy.text("empty.activity.title"), systemImage: "figure.walk", description: Text(MoveCopy.text("empty.activity.message")))
            } else {
                ForEach(todaysActivities.prefix(20)) { item in HStack { Text(item.statusRaw == "completed" ? "✓" : "–"); Text(exerciseName(for: item.exerciseID)); Spacer(); Text(item.performedAt, style: .time).foregroundStyle(.secondary) }.padding(.vertical, 4) }
            }
        }.padding(28) }
    }

    private func exerciseName(for id: String) -> String {
        ExerciseLibrary.all.first(where: { $0.id == id })?.name ?? id
    }
}
private struct StatCard: View { let value: String; let label: String; var body: some View { VStack(alignment: .leading) { Text(value).font(.title.bold()); Text(label).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 18)) } }
