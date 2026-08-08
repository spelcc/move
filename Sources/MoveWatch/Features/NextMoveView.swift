import SwiftUI

struct NextMoveView: View {
    @StateObject private var session = WatchSessionStore()
    var body: some View { VStack(spacing: 8) { Image(systemName: "figure.walk").font(.largeTitle); Text(session.nextExerciseName).multilineTextAlignment(.center); Text("Les rappels sont envoyés par l’iPhone.").font(.footnote).foregroundStyle(.secondary) }.padding() }
}
