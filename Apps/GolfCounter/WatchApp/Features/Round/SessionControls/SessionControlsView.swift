import SwiftUI
import WorkoutUI

/// 세션 가로 1/3 페이지 — 일시정지/재개 · 라운드 종료 (spec §4).
/// WorkoutUI의 공유 컨트롤 화면을 그대로 쓰되, 상단 왼쪽에 투명 자리채움을 둬
/// 내비게이션 바 영역 레이아웃을 다른 페이지와 맞춘다.
struct SessionControlsView: View {
    let isPaused: Bool
    let onPauseResume: () -> Void
    let onEnd: () -> Void

    var body: some View {
        WorkoutControlsView(isPaused: isPaused,
                            onPauseResume: onPauseResume,
                            onEnd: onEnd)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Color.clear.frame(width: 36, height: 36)
                }
            }
    }
}

#Preview {
    SessionControlsView(isPaused: false, onPauseResume: {}, onEnd: {})
}
