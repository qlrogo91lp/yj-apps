import SwiftUI
import WorkoutShareUI

/// 저장된 경기의 워크아웃 결과를 인스타그램 스토리로 공유한다.
/// 누적값이 없는 구버전 기록은 버튼 자체를 그리지 않는다 — Kit이 값 없는 지표 행을 빼는 것과 같은 규칙.
struct MatchShareButton: View {
    let match: Match

    /// Meta 개발자 대시보드에서 발급한 Facebook App ID. 빈 문자열이면 Kit이 딥링크를 만들지 않고
    /// iOS 공유 시트로 폴백한다. 발급 후 이 값만 바꾼다.
    private static let instagramAppID = ""

    var body: some View {
        if let result = match.workoutResult {
            WorkoutShareButton(
                result: result,
                style: WorkoutShareStyle(accentColor: .brand, logo: Image("RalliIcon")),
                instagramAppID: Self.instagramAppID
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
