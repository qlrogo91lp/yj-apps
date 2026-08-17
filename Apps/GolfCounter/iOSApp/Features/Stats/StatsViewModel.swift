import Foundation

/// 라운드 배열에서 통계 값을 계산한다. UI 프레임워크를 import하지 않는 순수 로직이다 (spec §5).
///
/// 9홀/18홀 혼재 왜곡을 피해 지표를 두 부류로 나눈다:
/// 라운드 단위(평균 타수·평균 오버파)는 18홀 라운드만, 홀 단위는 모든 라운드의 집계 대상 홀을 쓴다.
///
/// `@MainActor`를 붙이지 않는다 — `StatsView`가 저장 프로퍼티로 들고 있어야 하는데,
/// View의 프로퍼티 초기화는 nonisolated 컨텍스트라 격리된 init을 부를 수 없다.
struct StatsViewModel {
    /// 추이 차트에 그리는 최대 라운드 수.
    static let trendLimit = 10

    func summary(from rounds: [GolfRound]) -> StatsSummary {
        let fullRounds = rounds.filter(\.isFullRound)

        var summary = StatsSummary()
        summary.roundCount = rounds.count
        summary.fullRoundCount = fullRounds.count
        summary.trend = trend(from: rounds)
        summary.averageStrokes = average(fullRounds.map { Double($0.totalStrokes) })
        summary.averageOverPar = average(fullRounds.map { Double($0.relativeToPar) })
        summary.best = best(from: rounds)
        return summary
    }

    /// 최신 10개를 뽑아 오래된 순으로 되돌린다 — 차트 x축은 시간순이다.
    private func trend(from rounds: [GolfRound]) -> [StatsSummary.TrendPoint] {
        rounds
            .sorted { $0.startedAt > $1.startedAt }
            .prefix(Self.trendLimit)
            .reversed()
            .map { round in
                StatsSummary.TrendPoint(id: round.id,
                                        date: round.startedAt,
                                        relativeToPar: round.relativeToPar,
                                        isFullRound: round.isFullRound)
            }
    }

    /// 오버파가 가장 낮은 라운드. 동률이면 최신을 고른다.
    private func best(from rounds: [GolfRound]) -> StatsSummary.Best? {
        let sorted = rounds.sorted { lhs, rhs in
            if lhs.relativeToPar != rhs.relativeToPar {
                return lhs.relativeToPar < rhs.relativeToPar
            }
            return lhs.startedAt > rhs.startedAt
        }
        guard let winner = sorted.first else { return nil }
        return StatsSummary.Best(relativeToPar: winner.relativeToPar,
                                 holeCount: winner.recordedHoleCount)
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
