import SwiftUI

struct ExpandedView: View {
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
