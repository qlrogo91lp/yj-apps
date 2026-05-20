import SwiftUI

struct LockScreenView: View {
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
