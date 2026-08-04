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
                HStack {
                    ProgressCard(value: "\(stats.currentStreak) j", label: "série actuelle")
                    ProgressCard(value: "\(stats.longestStreak) j", label: "meilleure série")
                    ProgressCard(value: "\(stats.bestDayCompletedCount)", label: "record du jour")
                }
                Text("Par exercice").font(.title2.bold())
                ForEach(exerciseRows) { row in
                    HStack {
                        Text(row.id)
                        Spacer()
                        Text("\(row.totalAmount) • record \(row.bestDayAmount)").foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            }.padding(28)
        }
    }

    private var exerciseRows: [ExerciseStatistics] {
        let records = activities.map(\.record)
        return Set(records.map(\.exerciseID)).sorted().map { StatisticsService.forExercise(records, exerciseID: $0) }
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
