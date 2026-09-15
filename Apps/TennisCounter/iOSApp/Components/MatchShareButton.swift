import SwiftUI
import WorkoutShareUI

/// 저장된 경기의 워크아웃 결과 카드를 내보낸다 (공유 시트 · 스티커로 복사).
/// 누적값이 없는 구버전 기록은 버튼 자체를 그리지 않는다 — 카드 네 칸이 모두 워크아웃 누적값이라서.
struct MatchShareButton: View {
    let match: Match
    /// 툴바에 둘 때는 `.toolbar` — 배경을 툴바가 그려 옆의 기본 버튼과 질감이 맞는다.
    var appearance: WorkoutShareButtonAppearance = .standalone

    var body: some View {
        if let result = match.workoutResult {
            WorkoutShareButton(
                result: result,
                header: WorkoutShareHeader(
                    title: String(localized: "share_title_tennis"),
                    startedAt: match.shareStartedAt,
                    endedAt: match.shareEndedAt
                ),
                // 라임 원에는 Kit 가 검은 로고를 고른다 — 로고 색은 넘기지 않는다.
                style: WorkoutShareStyle(badgeColor: .brand, logo: Image("RalliIcon")),
                appearance: appearance
            )
        }
    }
}

#Preview("누적값 있음") {
    let match = Match()
    match.startedAt = Date().addingTimeInterval(-1800)
    match.endedAt = Date()
    match.workoutElapsedSeconds = 4800
    match.workoutCaloriesBurned = 500
    match.workoutTotalCaloriesBurned = 620
    match.averageHeartRate = 138
    return MatchShareButton(match: match).padding()
}

#Preview("구버전 기록 — 숨김") {
    let match = Match()
    match.durationSeconds = 1800
    return MatchShareButton(match: match).padding()
}
