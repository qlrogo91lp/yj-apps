#if os(watchOS)
    import SwiftUI
    import WorkoutCore

    /// 운동 경과시간 한 줄. 실행 중엔 시스템 `.timer` 텍스트가 매초 직접 갱신한다 — 우리 코드가
    /// metrics 발행 시점에 맞춰 다시 그릴 필요가 없어, HealthKit 콜백 간격이 불규칙해도
    /// (손목 내림·화면 꺼짐 등) 화면이 머물다가 몰아서 바뀌는 일이 없다.
    ///
    /// 정지 중엔 시스템 timer 대신 고정 문자열로 렌더링한다 — `.timer`는 멈춰 있는 것처럼
    /// 보여줄 수단이 없다.
    public struct WorkoutElapsedText: View {
        private let display: WorkoutElapsedDisplay

        public init(display: WorkoutElapsedDisplay) {
            self.display = display
        }

        public var body: some View {
            if let pausedAt = display.pausedAt {
                Text(WorkoutMetrics.formatSeconds(Int(display.elapsed(at: pausedAt))))
            } else {
                Text(display.referenceDate, style: .timer)
            }
        }
    }

    #Preview("실행 중") {
        WorkoutElapsedText(display: WorkoutElapsedDisplay(referenceDate: Date().addingTimeInterval(-1523)))
            .font(.system(size: 45, weight: .semibold, design: .rounded))
            .foregroundColor(.yellow)
            .background(Color.black)
    }

    #Preview("정지 중") {
        WorkoutElapsedText(display: WorkoutElapsedDisplay(
            referenceDate: Date().addingTimeInterval(-1523),
            pausedAt: Date()
        ))
        .font(.system(size: 45, weight: .semibold, design: .rounded))
        .foregroundColor(.yellow.opacity(0.5))
        .background(Color.black)
    }
#endif
