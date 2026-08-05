#if os(watchOS)
    import SwiftUI

    /// 워치 워크아웃 컨트롤 화면 — 일시정지/재개, 운동 종료.
    public struct WorkoutControlsView: View {
        private let isPaused: Bool
        private let isPauseAvailable: Bool
        private let onPauseResume: () -> Void
        private let onEnd: () -> Void

        public init(isPaused: Bool,
                    isPauseAvailable: Bool = true,
                    onPauseResume: @escaping () -> Void,
                    onEnd: @escaping () -> Void)
        {
            self.isPaused = isPaused
            self.isPauseAvailable = isPauseAvailable
            self.onPauseResume = onPauseResume
            self.onEnd = onEnd
        }

        public var body: some View {
            VStack(spacing: 12) {
                Button(action: onPauseResume) {
                    Label(
                        isPaused
                            ? String(localized: "workout_resume", bundle: .module)
                            : String(localized: "workout_pause", bundle: .module),
                        systemImage: isPaused ? "play.fill" : "pause.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .tint(.yellow)
                .disabled(!isPauseAvailable)

                Button(role: .destructive, action: onEnd) {
                    Label(String(localized: "workout_end", bundle: .module), systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
    }

    #Preview {
        WorkoutControlsView(isPaused: false, onPauseResume: {}, onEnd: {})
    }
#endif
