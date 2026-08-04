import SwiftUI
import SwiftData
import MoveCore

struct MoveProgressView: View {
    @Query private var activities: [ActivityEntity]
    @Query private var customExercises: [CustomExerciseEntity]
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
                        Text(exerciseName(for: row.id))
                        Spacer()
                        Text("\(row.totalAmount) • record \(row.bestDayAmount)").foregroundStyle(.secondary).monospacedDigit()
                    }
                }
                Text("Par catégorie").font(.title2.bold())
                ForEach(categoryRows) { row in
                    HStack {
                        Text(row.category.rawValue.capitalized)
                        Spacer()
                        ProgressView(value: Double(row.count), total: Double(max(1, categoryRows.map(\.count).max() ?? 1)))
                            .frame(width: 140)
                        Text("\(row.count)").monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }.padding(28)
        }
    }

    private var exerciseRows: [ExerciseStatistics] {
        let records = activities.map(\.record)
        return Set(records.map(\.exerciseID)).sorted().map { StatisticsService.forExercise(records, exerciseID: $0) }
    }

    private func exerciseName(for id: String) -> String {
        if let builtIn = ExerciseLibrary.all.first(where: { $0.id == id }) { return builtIn.name }
        return customExercises.first(where: { $0.id == id })?.name ?? id
    }

    private var categoryRows: [CategorySummary] {
        let records = activities.map(\.record).filter { $0.status == .completed }
        var counts: [ExerciseCategory: Int] = [:]
        for record in records {
            let category = ExerciseLibrary.all.first(where: { $0.id == record.exerciseID })?.category
                ?? customExercises.first(where: { $0.id == record.exerciseID }).flatMap { ExerciseCategory(rawValue: $0.categoryRaw) }
                ?? .free
            counts[category, default: 0] += 1
        }
        return counts.keys.sorted { $0.rawValue < $1.rawValue }.map { CategorySummary(category: $0, count: counts[$0] ?? 0) }
    }
}

private struct CategorySummary: Identifiable {
    let category: ExerciseCategory
    let count: Int
    var id: String { category.rawValue }
}

private struct ProgressCard: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading) { Text(value).font(.title.bold()); Text(label).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, alignment: .leading).padding().background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }
}
