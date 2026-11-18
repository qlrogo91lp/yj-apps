import SwiftUI
import WorkoutShareUI

/// 세션 상세에서 워크아웃 결과 카드를 내보낸다 (공유 시트 · 스티커로 복사).
struct SessionShareButton: View {
    let session: MatchSessionGroup

    private static func header(_ share: SessionShareData) -> WorkoutShareHeader {
        WorkoutShareHeader(title: String(localized: "share_title_tennis"), startedAt: share.startedAt, endedAt: share.endedAt)
    }

    private static var style: WorkoutShareStyle {
        WorkoutShareStyle(badgeColor: .brand, logo: Image("RalliIcon"))
    }

    @MainActor
    static func copySticker(_ share: SessionShareData) -> Bool {
        WorkoutShareExport.copySticker(result: share.result, header: header(share), style: style,
                                       accessory: EmptyView?.none)
    }

    var body: some View {
        if let share = SessionShareData(session: session) {
            WorkoutShareButton(
                result: share.result,
                header: Self.header(share),
                style: Self.style,
                appearance: .toolbar
            )
        }
    }
}
