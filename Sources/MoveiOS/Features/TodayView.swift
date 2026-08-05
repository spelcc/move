import SwiftUI
import MoveCore

struct TodayView: View {
    @AppStorage("move.nextReminderAt") private var nextTimestamp = 0.0
    @AppStorage("move.reminderQueueCount") private var queueCount = 0
    var body: some View {
        NavigationStack { VStack(spacing: 20) {
            Image(systemName: "figure.walk").font(.system(size: 54)).foregroundStyle(.tint)
            Text("Prêt à bouger ?").font(.title2.bold())
            if nextTimestamp > 0 { Text("Prochain rappel : \(Date(timeIntervalSince1970: nextTimestamp), style: .date) à \(Date(timeIntervalSince1970: nextTimestamp), style: .time)") }
            else { Text("Aucun rappel programmé") }
            Text("\(queueCount) rappels dans la file").font(.footnote).foregroundStyle(.secondary)
        }.padding()
            .navigationTitle("Aujourd’hui") }
    }
}
