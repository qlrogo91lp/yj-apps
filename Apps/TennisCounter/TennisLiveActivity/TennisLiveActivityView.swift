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
            } compactTrailing: {
                Text(context.state.yourPoint)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.orange)
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

// MARK: - 잠금화면 배너
private struct LockScreenView: View {
    let state: TennisActivityAttributes.ContentState

    var body: some View {
        HStack {
            if let start = state.workoutStartTime {
                Text(timerInterval: start...Date.distantFuture, countsDown: false)
                    .font(.system(size: 30, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(.yellow)
            }
            HStack(spacing: 24) {
                Text(state.myPoint)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.green)
                VStack(spacing: 4) {
                    Text("\(state.myGame) - \(state.yourGame)")
                        .font(.system(size: 18, weight: .semibold))
                    Text("\(state.mySet) - \(state.yourSet)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if state.isTieBreak {
                        Text("Tiebreak")
                            .font(.caption2)
                            .foregroundColor(Color(red: 0.6784, green: 1.0, blue: 0.2549))
                    }
                }
                Text(state.yourPoint)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Dynamic Island 확장 뷰
private struct ExpandedView: View {
    let state: TennisActivityAttributes.ContentState

    var body: some View {
        HStack {
            if let start = state.workoutStartTime {
                Text(timerInterval: start...Date.distantFuture, countsDown: false)
                    .font(.system(size: 30, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(.yellow)
            }

            HStack(spacing: 20) {
                Text(state.myPoint)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.green)
                VStack(spacing: 2) {
                    Text("\(state.myGame) : \(state.yourGame)")
                        .font(.system(size: 16, weight: .semibold))
                    Text("\(state.mySet) - \(state.yourSet)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(state.yourPoint)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.orange)
            }
        }
        .frame(maxWidth: .infinity)
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
