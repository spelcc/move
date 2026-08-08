import ActivityKit
import WidgetKit
import SwiftUI

struct MoveLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MoveActivityAttributes.self) { context in
            VStack(alignment: .leading) { Text(context.attributes.workoutID); Text(context.state.exerciseName); Text(timerInterval: Date()...context.state.endDate) }
                .activityBackgroundTint(.blue).padding()
        } dynamicIsland: { context in
            DynamicIsland { DynamicIslandExpandedRegion(.center) { Text(context.state.exerciseName) } } compactLeading: { Text("Move") } compactTrailing: { Text("\(context.state.step)/\(context.state.totalSteps)") } minimal: { Text("🏃") }
        }
    }
}

@main struct MoveWidgetsBundle: WidgetBundle { var body: some Widget { MoveLiveActivityWidget() } }
