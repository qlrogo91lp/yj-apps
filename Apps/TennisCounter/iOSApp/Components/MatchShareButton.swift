import SwiftUI
import WorkoutShareUI

/// 저장된 경기의 워크아웃 결과 카드를 공유 시트로 내보낸다.
/// 누적값이 없는 구버전 기록은 버튼 자체를 그리지 않는다 — Kit이 값 없는 지표 행을 빼는 것과 같은 규칙.
struct MatchShareButton: View {
    let match: Match

    var body: some View {
        if let result = match.workoutResult {
            WorkoutShareButton(
                result: result,
                style: WorkoutShareStyle(accentColor: .brand, logo: Image("RalliIcon"))
            )
        }
    }
}

#Preview("누적값 있음") {
    let match = Match()
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
