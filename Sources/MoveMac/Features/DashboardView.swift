import SwiftUI
import SwiftData
import MoveCore

struct DashboardView: View {
    @Query(sort: \ActivityEntity.performedAt, order: .reverse) private var activities: [ActivityEntity]
    @Bindable var store: MoveStore
    var body: some View {
        NavigationSplitView {
            List(selection: $store.selectedTab) {
                Label("Aujourd’hui", systemImage: "figure.run").tag("Aujourd’hui")
                Label("Séances", systemImage: "timer").tag("Séances")
                Label("Mouvements", systemImage: "list.bullet").tag("Mouvements")
                Label("Réglages", systemImage: "gear").tag("Réglages")
            }.navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            switch store.selectedTab {
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
            Text("Aujourd’hui").font(.largeTitle.bold())
            HStack { StatCard(value: "\(stats.completedCount)", label: "mouvements"); StatCard(value: "\(stats.totalRepetitions)", label: "répétitions"); StatCard(value: "\(stats.activeSeconds / 60) min", label: "actives") }
            Text("Historique").font(.title2.bold())
            ForEach(activities.prefix(20)) { item in HStack { Text(item.statusRaw == "completed" ? "✓" : "–"); Text(item.exerciseID); Spacer(); Text(item.performedAt, style: .time).foregroundStyle(.secondary) }.padding(.vertical, 4) }
        }.padding(28) }
    }
}
private struct StatCard: View { let value: String; let label: String; var body: some View { VStack(alignment: .leading) { Text(value).font(.title.bold()); Text(label).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 18)) } }
