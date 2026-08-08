import SwiftUI

struct NotificationOnboardingView: View {
    let request: () async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var requesting = false
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge").font(.system(size: 48)).foregroundStyle(.tint)
            Text("Ne manquez pas votre pause mouvement").font(.title2.bold()).multilineTextAlignment(.center)
            Text("Move programme les rappels sur l’iPhone et les transfère automatiquement vers l’Apple Watch.").multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Autoriser les notifications") { requesting = true; Task { _ = await request(); requesting = false; dismiss() } }.buttonStyle(.borderedProminent).disabled(requesting)
            Button("Plus tard") { dismiss() }.buttonStyle(.plain)
        }.padding()
    }
}
