import SwiftUI
import MoveCore

struct TodayView: View {
    @Binding var presentedExerciseID: String?
    @AppStorage("move.nextReminderAt") private var nextTimestamp = 0.0
    @AppStorage("move.reminderQueueCount") private var queueCount = 0
    var body: some View {
        NavigationStack { VStack(spacing: 20) {
            let exercise = ExerciseLibrary.all.first { $0.id == (presentedExerciseID ?? "") } ?? ExerciseLibrary.all.first!
            Text(exercise.emoji).font(.system(size: 54))
            Text(exercise.name).font(.title2.bold())
            Text("(exercise.defaultAmount) (metricLabel(exercise.metric))").foregroundStyle(.secondary)
            HStack {
                Button("C’est fait") { HistoryStore.append(.init(exerciseID: exercise.id, amount: exercise.defaultAmount, metric: exercise.metric, status: .completed, source: .hourly)); presentedExerciseID = nil }
                Button("Snooze") { HistoryStore.append(.init(exerciseID: exercise.id, amount: 0, metric: exercise.metric, status: .snoozed, source: .hourly)); presentedExerciseID = nil }
                Button("Autre") { presentedExerciseID = ExerciseLibrary.all.filter { $0.id != exercise.id }.randomElement()?.id }
            }.buttonStyle(.borderedProminent)
            if nextTimestamp > 0 { Text("Prochain rappel : \(Date(timeIntervalSince1970: nextTimestamp), style: .date) à \(Date(timeIntervalSince1970: nextTimestamp), style: .time)") }
            else { Text("Aucun rappel programmé") }
            Text("\(queueCount) rappels dans la file").font(.footnote).foregroundStyle(.secondary)
        }.padding()
            .navigationTitle("Aujourd’hui") }
    }
    private func metricLabel(_ metric: ExerciseMetric) -> String { switch metric { case .repetitions: return "répétitions"; case .seconds: return "secondes"; case .minutes: return "minutes"; case .free: return "à ton rythme" } }
}
