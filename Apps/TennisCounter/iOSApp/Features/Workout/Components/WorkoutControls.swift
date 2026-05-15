import SwiftUI

struct WorkoutControls: View {
    let isPaused: Bool
    let onPauseResume: () -> Void
    let onEnd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPauseResume) {
                HStack(spacing: 8) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text(isPaused ? String(localized: "workout_resume") : String(localized: "workout_pause"))
                        .font(.system(size: 17, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.yellow)
                .foregroundColor(.black)
                .clipShape(Capsule())
            }
            .accessibilityLabel(isPaused ? String(localized: "workout_resume") : String(localized: "workout_pause"))

            Button(role: .destructive, action: onEnd) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 20))
                    .frame(width: 56, height: 56)
                    .background(Color.red.opacity(0.85))
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
            .accessibilityLabel(String(localized: "workout_end"))
        }
        .padding(.bottom, 16)
    }
}

#Preview {
    WorkoutControls(isPaused: false, onPauseResume: {}, onEnd: {})
        .background(Color.black)
}
