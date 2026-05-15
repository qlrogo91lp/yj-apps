import SwiftUI

struct WorkoutControls: View {
    let isPaused: Bool
    let onPauseResume: () -> Void
    let onEnd: () -> Void

    var body: some View {
        HStack(spacing: 24) {
            Button(action: onPauseResume) {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 36))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(Color.yellow.opacity(0.9))
            .foregroundColor(.black)
            .clipShape(Circle())
            .accessibilityLabel(isPaused ? String(localized: "workout_resume") : String(localized: "workout_pause"))

            Button(role: .destructive, action: onEnd) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 32))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(Color.red.opacity(0.85))
            .foregroundColor(.white)
            .clipShape(Circle())
            .accessibilityLabel(String(localized: "workout_end"))
        }
        .padding(.bottom, 16)
    }
}

#Preview {
    WorkoutControls(isPaused: false, onPauseResume: {}, onEnd: {})
}
