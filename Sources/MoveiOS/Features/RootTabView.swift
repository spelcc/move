import SwiftUI

struct RootTabView: View {
    private enum Tab: Hashable { case today, workouts, history, settings }

    @AppStorage("move.notificationOnboardingSeen") private var onboardingSeen = false
    @Bindable var store: iOSAppStore
    @State private var selectedTab: Tab = .today
    @State private var presentedExerciseID: String?

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(store: store, presentedExerciseID: $presentedExerciseID)
                .tabItem { Label("Aujourd’hui", systemImage: "figure.walk") }
                .tag(Tab.today)
            iOSWorkoutLibraryView(store: store)
                .tabItem { Label("Workouts", systemImage: "figure.run") }
                .tag(Tab.workouts)
            HistoryView()
                .tabItem { Label("Historique", systemImage: "clock") }
                .tag(Tab.history)
            iOSReminderSettingsView(store: store)
                .tabItem { Label("Réglages", systemImage: "gear") }
                .tag(Tab.settings)
        }
        .onChange(of: store.pendingRoute) { _, route in
            apply(route)
        }
        .onAppear { apply(store.consumePendingRoute()) }
        .sheet(isPresented: Binding(
            get: { !onboardingSeen },
            set: { if !$0 { onboardingSeen = true } }
        )) {
            NotificationOnboardingView(request: { await store.requestNotifications() })
        }
    }

    private func apply(_ route: iOSAppRoute?) {
        guard case let .today(exerciseID) = route else { return }
        presentedExerciseID = exerciseID
        selectedTab = .today
        store.pendingRoute = nil
    }
}
