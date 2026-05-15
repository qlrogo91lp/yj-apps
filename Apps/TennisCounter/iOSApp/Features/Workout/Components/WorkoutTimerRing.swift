import SwiftUI

struct WorkoutTimerRing: View {
    let formattedElapsed: String
    let isPaused: Bool

    private var ringColor: Color { isPaused ? .yellow : .green }

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.2), lineWidth: 12)
                .frame(width: 240, height: 240)
            Circle()
                .trim(from: 0, to: 1)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .frame(width: 240, height: 240)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 4) {
                Text(String(localized: "workout_elapsed_label"))
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white)
                Text(formattedElapsed)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundColor(.yellow)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                    .frame(width: 180)
            }
        }
    }
}
