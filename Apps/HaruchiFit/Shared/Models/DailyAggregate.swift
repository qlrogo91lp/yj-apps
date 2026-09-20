import Foundation

/// 잔디 한 칸. `WorkoutRecord` 여러 건을 **하루 단위로 접은** 결과다 (D3).
///
/// 농도에 쓰는 건 `totalSeconds` 하나지만 나머지도 같은 한 번의 순회에서 나온다 —
/// Phase 4 의 홈 "이번 주 운동 구성 바" · 달력 월 요약("12회 · 9.2시간") · 통계 비율이
/// 전부 이 값을 쓴다. 농도만 내는 타입을 만들면 그때 타입을 다시 고치게 된다 (스펙 2절).
struct DailyAggregate: Equatable, Identifiable {
    /// 자정으로 정규화된 날짜. **칸의 정체성이다.**
    let day: Date
    /// 농도 계산의 입력. 세그먼트 합이 아니라 레코드의 `totalSeconds` 합이다 —
    /// 수동 기록과 HealthKit import 기록은 세그먼트가 없을 수 있다 (스펙 4.2).
    let totalSeconds: Int
    let strengthSeconds: Int
    let cardioSeconds: Int
    /// 칼로리 기준으로 전환했을 때의 입력. 칼로리를 가진 레코드가 하나도 없으면 nil 이다.
    let totalCalories: Double?
    /// 달력 월 요약과 통계 세션 카운트 (D2).
    let sessionCount: Int

    var id: Date {
        day
    }
}
