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

    var totalStrokes: Int { holeScores.reduce(0, +) }
    var totalPutts: Int { puttCounts.reduce(0, +) }
    var totalPar: Int { holePars.reduce(0, +) }
    var relativeToPar: Int { totalStrokes - totalPar }
}
