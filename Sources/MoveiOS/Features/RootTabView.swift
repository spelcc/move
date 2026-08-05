import SwiftUI
import MoveCore

struct RootTabView: View {
    @AppStorage("move.notificationOnboardingSeen") private var onboardingSeen = false
    let requestAuthorization: () async -> Bool
    var body: some View {
        TabView {
            TodayView().tabItem { Label("Aujourd’hui", systemImage: "figure.walk") }
            Text("Séances").tabItem { Label("Séances", systemImage: "list.bullet") }
            Text("Historique").tabItem { Label("Historique", systemImage: "clock") }
            iOSReminderSettingsView().tabItem { Label("Réglages", systemImage: "gear") }
        }.sheet(isPresented: Binding(get: { !onboardingSeen }, set: { if $0 == false { onboardingSeen = true } })) {
            NotificationOnboardingView(request: requestAuthorization)
        }
    }
}
