import SwiftUI

struct LiveActivityView: View {
    let state: TennisActivityAttributes.ContentState
    let matchMode: String

    var body: some View {
        VStack {
            HStack(spacing: 6) {
                Image("RalliIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .padding(3)
                    .background(Circle().fill(Color.brand))

                Text("Ralli")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.green)
                    .italic()

                Spacer()
            }

            HStack {
                if let start = state.workoutStartTime {
                    Text(timerInterval: start ... Date.distantFuture, countsDown: false)
                        .font(.system(size: 30, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(.yellow)
                }
                HStack(spacing: 12) {
                    Text(state.myPoint)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    VStack(spacing: 4) {
                        Text("\(state.myGame) : \(state.yourGame)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        if matchMode != "one_set" {
                            Text("\(state.mySet) - \(state.yourSet)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        if state.isTieBreak {
                            Text("Tiebreak")
                                .font(.caption2)
                                .foregroundColor(Color.brand)
                        }
                    }
                    Text(state.yourPoint)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
                .fixedSize()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black)
    }
}
