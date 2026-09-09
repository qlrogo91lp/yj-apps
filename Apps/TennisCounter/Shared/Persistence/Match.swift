import Foundation
import SwiftData
import WorkoutCore

@Model
class Match {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var caloriesBurned: Double?
    /// 활동 + 휴식. CloudKit 요구사항상 optional이며, 총 칼로리 도입 전 기록은 nil이다.
    var totalCaloriesBurned: Double?
    /// 이 경기 구간의 활동 시간(일시정지 제외). 워크아웃 누적값이 아니다.
    var durationSeconds: Int?
    /// 워크아웃 시작부터 이 경기 종료 시점까지의 누적값. Summary가 workoutSessionId로
    /// 그룹핑해 그룹당 최댓값만 합산한다 — 단순 합산하면 같은 값을 여러 번 세게 된다.
    /// 누적값 도입 전 기록은 nil이다.
    var workoutElapsedSeconds: Int?
    var workoutCaloriesBurned: Double?
    var workoutTotalCaloriesBurned: Double?
    var opponentName: String?
    var myTotalSets: Int = 0
    var yourTotalSets: Int = 0
    var isCompleted: Bool = false
    /// CloudKit 요구사항: optional + inverse 지정
    @Relationship(deleteRule: .cascade, inverse: \SetRecord.match) var sets: [SetRecord]?

    /// 이 경기의 고유 식별자. 폰·워치가 SessionStartMessage로 공유한다. 저장 시 중복 제거 키.
    /// CloudKit 요구사항상 optional이며, matchId 도입 전 기록은 nil이다.
    var matchId: UUID?

    var workoutSessionId: UUID?
    var mode: String = MatchFormat.oneSet.rawValue
    var noAdRule: Bool = true
    var resultRaw: String = "win"
    var averageHeartRate: Double?

    var matchFormat: MatchFormat {
        get { MatchFormat(rawValue: mode) ?? .oneSet }
        set { mode = newValue.rawValue }
    }

    init() {}
}

extension Match {
    /// 공유 카드용 워크아웃 결과. **워크아웃 누적값** 기준이다 — 카드는 경기 한 판이 아니라
    /// 운동 세션을 자랑하는 용도라서, 경기 구간값(`durationSeconds`·`caloriesBurned`)은 쓰지 않는다.
    /// 누적값 도입(1.1.6) 전 기록은 nil이므로 호출부가 버튼을 숨긴다.
    var workoutResult: WorkoutResult? {
        guard let elapsed = workoutElapsedSeconds,
              let calories = workoutCaloriesBurned
        else { return nil }
        return WorkoutResult(
            durationSeconds: elapsed,
            caloriesBurned: calories,
            averageHeartRate: averageHeartRate,
            totalCaloriesBurned: workoutTotalCaloriesBurned ?? 0
        )
    }
}
