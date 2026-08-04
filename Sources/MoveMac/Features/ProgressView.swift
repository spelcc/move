import SwiftUI
import SwiftData
import MoveCore

struct MoveProgressView: View {
    @Query private var activities: [ActivityEntity]
    var body: some View {
        let stats = StatisticsService.currentWeek(activities.map(\.record))
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Progression").font(.largeTitle.bold())
                Text("Cette semaine").font(.title2.bold())
                HStack {
                    ProgressCard(value: "\(stats.activeDays)", label: "jours actifs")
                    ProgressCard(value: "\(stats.completedCount)", label: "mouvements")
                    ProgressCard(value: "\(stats.totalRepetitions)", label: "répétitions")
                    ProgressCard(value: "\(stats.activeSeconds / 60) min", label: "actives")
                }
                Text("Série actuelle : \(stats.currentStreak) jour\(stats.currentStreak == 1 ? "" : "s")").font(.headline)
            }.padding(28)
        }
    }
}

private struct ProgressCard: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading) { Text(value).font(.title.bold()); Text(label).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, alignment: .leading).padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }
}
