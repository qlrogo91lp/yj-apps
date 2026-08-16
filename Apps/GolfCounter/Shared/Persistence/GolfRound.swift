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

    /// holePars/puttCounts는 holeScores와 같은 개수만 유효 — 아직 파가 없는 홀의 배열 길이 불일치를 자동으로 무시한다
    var relativeToPar: Int {
        zip(holeScores, holePars).reduce(0) { $0 + $1.0 - $1.1 }
    }

    /// 파가 기록된 홀 수. 워치에서 건너뛴 홀(par == 0)은 세지 않는다 (spec §3).
    /// 기록 리스트의 `N홀` 뱃지와 통계의 18홀 판정이 같은 값을 쓴다.
    var recordedHoleCount: Int {
        holePars.filter { $0 > 0 }.count
    }

    /// 18홀을 끝까지 기록한 라운드. 총타수 기반 통계는 이 라운드만 집계한다 (spec §5).
    var isFullRound: Bool {
        recordedHoleCount == 18
    }
}
