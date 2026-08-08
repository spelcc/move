import SwiftUI
import SwiftData
import MoveCore
import MoveShared

struct TodayView: View {
    @Bindable var store: iOSAppStore
    @Binding var presentedExerciseID: String?
    @Query(sort: \ActivityEntity.performedAt, order: .reverse) private var activities: [ActivityEntity]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    progressCards
                    Divider()
                    if let exercise = selectedExercise {
                        Text(exercise.emoji).font(.system(size: 54))
                        Text(exercise.name).font(.title2.bold())
                        Text("\(exercise.defaultAmount) \(metricLabel(exercise.metric))")
                            .foregroundStyle(.secondary)
                        if exercise.metric == .seconds {
                            iOSMovementTimerView(durationSeconds: exercise.defaultAmount) {
                                store.record(
                                    exercise: exercise,
                                    status: .completed,
                                    amount: exercise.defaultAmount,
                                    metric: .seconds
                                )
                                presentedExerciseID = nil
                            }
                            .id(exercise.id)
                        }
                        HStack {
                            if exercise.metric != .seconds {
                                Button("C’est fait") {
                                    store.record(exercise: exercise, status: .completed)
                                    presentedExerciseID = nil
                                }
                            }
                            Button("Snooze") {
                                store.snooze(exercise)
                                presentedExerciseID = nil
                            }
                            Button("Autre") {
                                presentedExerciseID = store.availableExercises
                                    .filter { $0.id != exercise.id }
                                    .randomElement()?.id
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        ContentUnavailableView(
                            "Aucun mouvement actif",
                            systemImage: "figure.walk",
                            description: Text("Active un mouvement depuis Réglages › Mouvements.")
                        )
                    }
                    if let next = store.reminderState.nextReminderAt {
                        Text("Prochain rappel : \(next, style: .date) à \(next, style: .time)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Aucun rappel programmé")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Aujourd’hui")
        }
    }

    private var selectedExercise: Exercise? {
        store.exercise(withID: presentedExerciseID) ?? store.availableExercises.first
    }

    private var progressCards: some View {
        let records = activities.map(\.record)
        let today = Calendar.current.startOfDay(for: .now)
        let todayStats = StatisticsService.calculate(records, since: today)
        let allStats = StatisticsService.calculate(records)
        return LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
            iOSProgressCard(value: "\(todayStats.completedCount)", label: "Mouvements")
            iOSProgressCard(value: "\(todayStats.totalRepetitions)", label: "Répétitions")
            iOSProgressCard(value: "\(todayStats.activeSeconds / 60) min", label: "Actives")
            iOSProgressCard(value: "\(allStats.currentStreak) j", label: "Série")
        }
    }

    private func metricLabel(_ metric: ExerciseMetric) -> String {
        switch metric {
        case .repetitions: "répétitions"
        case .seconds: "secondes"
        case .minutes: "minutes"
        case .free: "à ton rythme"
        }
    }
}

private struct iOSProgressCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.title2.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }
}
