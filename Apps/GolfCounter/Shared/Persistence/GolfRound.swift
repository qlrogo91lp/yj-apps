import Foundation
import SwiftData

/// 한 라운드의 전체 기록. CloudKit 규칙: 전 프로퍼티 기본값/optional, .unique 금지.
/// 홀 데이터는 관계 대신 병렬 배열 — 인덱스 = 홀 번호 - 1.
@Model
final class GolfRound {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var courseName: String?
    var holeScores: [Int] = []
    var holePars: [Int] = []
    var puttCounts: [Int] = []
    var calories: Double = 0
    var avgHeartRate: Double = 0
    var distanceMeters: Double = 0
    var steps: Int = 0

    init() {}

    var totalStrokes: Int {
        holeScores.reduce(0, +)
    }

    var totalPutts: Int {
        puttCounts.reduce(0, +)
    }

    var totalPar: Int {
        holePars.reduce(0, +)
    }

    /// 집계 대상 홀(파와 타수가 모두 있는 홀)만 더한다. 규칙은 `ScoreAggregate` 참조 (history spec §3).
    var relativeToPar: Int {
        ScoreAggregate.relativeToPar(holeScores: holeScores, holePars: holePars)
    }

    /// 집계 대상 홀(파와 타수가 모두 있는 홀)의 개수. 규칙은 `ScoreAggregate` 참조 (invariant spec §7).
    /// 기록 리스트의 `N홀` 뱃지와 통계의 18홀 판정이 같은 값을 쓴다.
    var recordedHoleCount: Int {
        ScoreAggregate.recordedHoleCount(holeScores: holeScores, holePars: holePars)
    }

    /// 18홀을 끝까지 기록한 라운드. 총타수 기반 통계는 이 라운드만 집계한다 (history spec §5).
    var isFullRound: Bool {
        recordedHoleCount == 18
    }
}
