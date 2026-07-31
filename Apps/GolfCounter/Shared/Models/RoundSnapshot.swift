import Foundation

/// 라운드 진행 중 상태 스냅샷.
/// 워치 크래시/강제종료 복구와 컴플리케이션 표시 데이터원을 겸한다 (spec §3).
struct RoundSnapshot: Codable, Equatable {
    var startedAt: Date
    var courseName: String?
    var currentHoleIndex: Int // 0-based, 인덱스 = 홀 번호 - 1
    var holeScores: [Int]
    var holePars: [Int]
    var puttCounts: [Int]

    var currentHoleNumber: Int { currentHoleIndex + 1 }
    var totalStrokes: Int { holeScores.reduce(0, +) }
    var relativeToPar: Int { totalStrokes - holePars.reduce(0, +) }
}
