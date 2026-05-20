import ActivityKit
import SwiftUI
import WidgetKit

struct TennisLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TennisActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    ExpandedView(state: context.state)
                }
            } compactLeading: {
                Text(context.state.myPoint)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.leading, 5)
                    .padding(.trailing, 2)
            } compactTrailing: {
                Text(context.state.yourPoint)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.orange)
                    .padding(.leading, 2)
                    .padding(.trailing, 5)
            } minimal: {
                Image("RalliIcon")
                    .resizable()
                    .scaledToFit()
                    .padding(3)
                    .background(Circle().fill(Color(red: 0.6784, green: 1.0, blue: 0.2549)))
            }
        }
    }
}

private extension TennisActivityAttributes {
    static let preview = TennisActivityAttributes(matchMode: "3세트")
}

#Preview("Lock Screen", as: .content, using: TennisActivityAttributes.preview) {
    TennisLiveActivityWidget()
} contentStates: {
    TennisActivityAttributes.ContentState.preview
    TennisActivityAttributes.ContentState.tieBreak
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: TennisActivityAttributes.preview) {
    TennisLiveActivityWidget()
} contentStates: {
    TennisActivityAttributes.ContentState.preview
    TennisActivityAttributes.ContentState.tieBreak
}

#Preview("Dynamic Island Minimal", as: .dynamicIsland(.minimal), using: TennisActivityAttributes.preview) {
    TennisLiveActivityWidget()
} contentStates: {
    TennisActivityAttributes.ContentState.preview
}

private extension TennisActivityAttributes.ContentState {
    static let preview = TennisActivityAttributes.ContentState(
        myPoint: "40", yourPoint: "30",
        myGame: 3, yourGame: 2,
        mySet: 1, yourSet: 0,
        isTieBreak: false,
        workoutStartTime: Date.now - 1234
    )
    static let tieBreak = TennisActivityAttributes.ContentState(
        myPoint: "7", yourPoint: "6",
        myGame: 6, yourGame: 6,
        mySet: 1, yourSet: 1,
        isTieBreak: true,
        workoutStartTime: Date.now - 3600
    )
}
