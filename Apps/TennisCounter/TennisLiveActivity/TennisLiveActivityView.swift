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
            } compactTrailing: {
                Text(context.state.yourPoint)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.orange)
            } minimal: {
                Text(context.state.myPoint)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.green)
            }
        }
    }
}

// MARK: - 잠금화면 배너

private struct LockScreenView: View {
    let state: TennisActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 24) {
            VStack(spacing: 2) {
                Text("ME")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(state.myPoint)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.green)
            }
            VStack(spacing: 4) {
                Text("\(state.myGame) - \(state.yourGame)")
                    .font(.system(size: 18, weight: .semibold))
                Text("\(state.mySet) - \(state.yourSet)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if state.isTieBreak {
                    Text("TIEBREAK")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
            }
            VStack(spacing: 2) {
                Text("OPP")
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
        HStack(spacing: 20) {
            Text(state.myPoint)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.green)
            VStack(spacing: 2) {
                Text("\(state.myGame) : \(state.yourGame)")
                    .font(.system(size: 16, weight: .semibold))
                Text("Set \(state.mySet) - \(state.yourSet)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(state.yourPoint)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.orange)
        }
    }
}
