import Foundation

/// 통계 탭이 표시하는 값 전부. `StatsViewModel`이 라운드 배열에서 계산한다 (spec §5).
/// 중첩 타입으로 묶어 두어 파일 하나가 최상위 타입 하나를 갖는다.
struct StatsSummary: Equatable {
    struct TrendPoint: Equatable, Identifiable {
        let id: UUID
        let date: Date
        let relativeToPar: Int
        /// 18홀 라운드와 그 외(9홀·중단)를 다른 심볼로 그린다.
        let isFullRound: Bool
    }

    /// 베스트 스코어. 9홀 라운드가 유리하게 잡힐 수 있어 홀 수를 함께 들고 다닌다.
    struct Best: Equatable {
        let relativeToPar: Int
        let holeCount: Int
    }

    enum Bucket: String, CaseIterable, Identifiable {
        case birdieOrBetter
        case par
        case bogey
        case doubleOrWorse

        var id: String {
            rawValue
        }

        static func of(overPar: Int) -> Bucket {
            switch overPar {
            case ..<0: .birdieOrBetter
            case 0: .par
            case 1: .bogey
            default: .doubleOrWorse
            }
        }
    }

    struct BucketCount: Equatable, Identifiable {
        let bucket: Bucket
        let count: Int
        /// 0…1. 집계 대상 홀이 하나도 없으면 0이다.
        let ratio: Double

        var id: String {
            bucket.rawValue
        }
    }

    struct ParPerformance: Equatable, Identifiable {
        let par: Int
        /// 해당 파의 집계 대상 홀이 없으면 nil.
        let averageOverPar: Double?

        var id: Int {
            par
        }
    }

    var roundCount = 0
    /// 18홀을 끝까지 기록한 라운드 수. 평균 타수·평균 오버파의 모집단이다.
    var fullRoundCount = 0
    var trend: [TrendPoint] = []
    var averageStrokes: Double?
    var averageOverPar: Double?
    var best: Best?
    var puttsPerHole: Double?
    var distribution: [BucketCount] = []
    var parPerformance: [ParPerformance] = []
}
