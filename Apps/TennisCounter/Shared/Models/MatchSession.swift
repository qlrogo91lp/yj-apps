import Foundation

class MatchSession {
    let id: UUID
    let workoutSessionId: UUID
    let options: MatchOptions
    let startedAt: Date
    var endedAt: Date?
    var result: MatchResult?

    var mySetScore: Int = 0
    var yourSetScore: Int = 0
    var completedSets: [SetScore] = []

    /// 활동 에너지 기준 경기 구간 계산용 시작·종료값.
    let kcalAtStart: Double
    var kcalAtEnd: Double?
    /// 활동 + 휴식 기준. 경기 구간 총 칼로리 = totalKcalAtEnd - totalKcalAtStart.
    let totalKcalAtStart: Double
    var totalKcalAtEnd: Double?
    var averageHeartRate: Double?

    init(id: UUID = UUID(), workoutSessionId: UUID, options: MatchOptions,
         startedAt: Date = Date(), kcalAtStart: Double, totalKcalAtStart: Double = 0)
    {
        self.id = id
        self.workoutSessionId = workoutSessionId
        self.options = options
        self.startedAt = startedAt
        self.kcalAtStart = kcalAtStart
        self.totalKcalAtStart = totalKcalAtStart
    }
}
