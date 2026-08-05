#if os(iOS)
    import SwiftUI

    /// 일시정지/재개 + 종료 버튼 쌍.
    struct WorkoutControls: View {
        let isPaused: Bool
        let isPauseAvailable: Bool
        let onPauseResume: () -> Void
        let onEnd: () -> Void

        private var pauseTitle: String {
            isPaused
                ? String(localized: "workout_resume", bundle: .module)
                : String(localized: "workout_pause", bundle: .module)
        }

        var body: some View {
            HStack(spacing: 12) {
                Button(action: onPauseResume) {
                    HStack(spacing: 8) {
                        Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(pauseTitle)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isPauseAvailable ? Color.yellow : Color.yellow.opacity(0.3))
                    .foregroundColor(.black)
                    .clipShape(Capsule())
                }
                .disabled(!isPauseAvailable)
                .accessibilityLabel(pauseTitle)

                Button(role: .destructive, action: onEnd) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 20))
                        .frame(width: 56, height: 56)
                        .background(Color.red.opacity(0.85))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }
                .accessibilityLabel(String(localized: "workout_end", bundle: .module))
            }
            .padding(.bottom, 16)
        }
    }
#endif
