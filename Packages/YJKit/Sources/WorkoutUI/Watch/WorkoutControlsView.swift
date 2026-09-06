#if os(watchOS)
    import SwiftUI

    /// 워치 워크아웃 컨트롤 화면 — 일시정지/재개, 운동 종료.
    ///
    /// `modeSelection` 을 주면 일시정지 **위에** 전환 행이 붙는다. 항목의 제목과 색은
    /// 앱이 소유한다. 주지 않으면 기존 2버튼 그대로다.
    public struct WorkoutControlsView: View {
        private let isPaused: Bool
        private let isPauseAvailable: Bool
        private let modeSelection: WorkoutModeSelection?
        private let onPauseResume: () -> Void
        private let onEnd: () -> Void

        public init(isPaused: Bool,
                    isPauseAvailable: Bool = true,
                    modeSelection: WorkoutModeSelection? = nil,
                    onPauseResume: @escaping () -> Void,
                    onEnd: @escaping () -> Void)
        {
            self.isPaused = isPaused
            self.isPauseAvailable = isPauseAvailable
            self.modeSelection = modeSelection
            self.onPauseResume = onPauseResume
            self.onEnd = onEnd
        }

        public var body: some View {
            VStack(spacing: 12) {
                if let modeSelection {
                    WorkoutModeRow(selection: modeSelection)
                }

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

    #Preview("기본") {
        WorkoutControlsView(isPaused: false, onPauseResume: {}, onEnd: {})
    }

    #Preview("전환 행") {
        WorkoutControlsView(
            isPaused: false,
            modeSelection: WorkoutModeSelection(
                options: [WorkoutModeOption(id: 0, title: "근력", tint: .orange),
                          WorkoutModeOption(id: 1, title: "유산소", tint: .blue)],
                selectedID: 0,
                onSelect: { _ in }
            ),
            onPauseResume: {},
            onEnd: {}
        )
    }
#endif
