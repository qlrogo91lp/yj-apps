import SwiftData
import SwiftUI

/// 통계 탭. 기간 필터를 두지 않는다 — 골프는 라운드 빈도가 낮아 주/월 세그먼트가 빈 화면을 만든다 (spec §5).
struct StatsView: View {
    @Query(sort: \GolfRound.startedAt, order: .reverse) private var rounds: [GolfRound]
    private let viewModel = StatsViewModel()

    private var summary: StatsSummary {
        viewModel.summary(from: rounds)
    }

    var body: some View {
        NavigationStack {
            Group {
                if rounds.isEmpty {
                    EmptyRounds()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            trendSection
                            cardsSection
                            distributionSection
                            parSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("통계")
        }
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("오버파 추이", caption: "총 \(summary.roundCount)라운드")
            OverParTrendChart(points: summary.trend)
        }
    }

    private var cardsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "평균 타수",
                     value: summary.averageStrokes.map { String(format: "%.1f", $0) } ?? "–",
                     caption: fullRoundCaption)
            StatCard(title: "베스트 스코어",
                     value: summary.best.map { ScoreFormat.relativeToPar($0.relativeToPar) } ?? "–",
                     caption: summary.best.map { "\($0.holeCount)홀" })
            StatCard(title: "평균 오버파",
                     value: summary.averageOverPar.map(ScoreFormat.averageRelativeToPar) ?? "–",
                     caption: fullRoundCaption)
            StatCard(title: "홀당 평균 퍼트",
                     value: summary.puttsPerHole.map { String(format: "%.1f", $0) } ?? "–")
        }
    }

    private var distributionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("스코어 분포", caption: nil)
            ScoreDistributionChart(buckets: summary.distribution)
        }
    }

    private var parSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("파별 성적", caption: "홀당 평균 오버파")
            ParPerformanceRow(items: summary.parPerformance)
        }
    }

    /// 평균 타수·평균 오버파의 모집단을 밝힌다 — 9홀 라운드가 빠져 있다는 사실이 드러나야 한다.
    private var fullRoundCaption: String {
        "18홀 라운드 \(summary.fullRoundCount)개 기준"
    }

    private func sectionHeader(_ title: String, caption: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)
            Spacer()
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
