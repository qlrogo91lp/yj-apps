import SwiftUI
import WorkoutShareUI

/// 세션 상세에서 워크아웃 결과 카드를 내보낸다 (공유 시트 · 스티커로 복사).
struct SessionShareButton: View {
    let session: MatchSessionGroup

    var body: some View {
        if let share = SessionShareData(session: session) {
            WorkoutShareButton(
                result: share.result,
                header: WorkoutShareHeader(
                    title: String(localized: "share_title_tennis"),
                    startedAt: share.startedAt,
                    endedAt: share.endedAt
                ),
                style: WorkoutShareStyle(badgeColor: .brand, logo: Image("RalliIcon")),
                appearance: .toolbar
            )
        }
    }
}
