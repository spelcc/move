import SwiftUI
import MoveCore

struct RootTabView: View {
    @AppStorage("move.notificationOnboardingSeen") private var onboardingSeen = false
    let requestAuthorization: () async -> Bool
    @State private var selectedTab = 0
    @State private var presentedExerciseID: String?
    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(presentedExerciseID: $presentedExerciseID).tabItem { Label("Aujourd’hui", systemImage: "figure.walk") }.tag(0)
            WorkoutTimerView().tabItem { Label("Timer", systemImage: "timer") }.tag(1)
            HistoryView().tabItem { Label("Historique", systemImage: "clock") }.tag(2)
            iOSReminderSettingsView().tabItem { Label("Réglages", systemImage: "gear") }
        }.onReceive(NotificationCenter.default.publisher(for: .moveiOSNotificationAction)) { note in
            if let id = note.userInfo?["exerciseID"] as? String { presentedExerciseID = id; selectedTab = 0 }
        }.sheet(isPresented: Binding(get: { !onboardingSeen }, set: { if $0 == false { onboardingSeen = true } })) {
            NotificationOnboardingView(request: requestAuthorization)
        }
    }
}
