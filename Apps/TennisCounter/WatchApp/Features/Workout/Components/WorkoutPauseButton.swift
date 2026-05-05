import SwiftUI

struct WorkoutPauseButton: View {
    let isPaused: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 20, weight: .semibold))
                Text(isPaused ? String(localized: "workout_resume") : String(localized: "workout_pause"))
                    .font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(.yellow.opacity(0.9))
        .foregroundColor(.black)
    }
}
