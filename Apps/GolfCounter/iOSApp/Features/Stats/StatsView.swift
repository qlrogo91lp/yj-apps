import SwiftData
import SwiftUI

/// 통계 탭. 기간 필터를 두지 않는다 — 골프는 라운드 빈도가 낮아 주/월 세그먼트가 빈 화면을 만든다 (spec §5).
struct StatsView: View {
    @Query(sort: \GolfRound.startedAt, order: .reverse) private var rounds: [GolfRound]
    private let viewModel = StatsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if rounds.isEmpty {
                    EmptyRounds()
                } else {
                    let summary = viewModel.summary(from: rounds)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            trendSection(summary)
                            cardsSection(summary)
                            distributionSection(summary)
                            parSection(summary)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(String(localized: "stats_title"))
        }
    }

    private func trendSection(_ summary: StatsSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(String(localized: "stats_section_trend"),
                          caption: String(format: String(localized: "stats_round_total"), summary.roundCount))
            OverParTrendChart(points: summary.trend)
        }
    }

    private func cardsSection(_ summary: StatsSummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: String(localized: "stats_card_avg_strokes"),
                     value: summary.averageStrokes.map { String(format: "%.1f", $0) } ?? "–",
                     caption: fullRoundCaption(summary))
            StatCard(title: String(localized: "stats_card_best"),
                     value: summary.best.map { ScoreFormat.relativeToPar($0.relativeToPar) } ?? "–",
                     caption: summary.best.map {
                         String(format: String(localized: "stats_best_holes"), $0.holeCount)
                     })
            StatCard(title: String(localized: "stats_card_avg_over_par"),
                     value: summary.averageOverPar.map(ScoreFormat.averageRelativeToPar) ?? "–",
                     caption: fullRoundCaption(summary))
            StatCard(title: String(localized: "stats_card_putts_per_hole"),
                     value: summary.puttsPerHole.map { String(format: "%.1f", $0) } ?? "–")
        }
    }

    private func distributionSection(_ summary: StatsSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(String(localized: "stats_section_distribution"), caption: nil)
            ScoreDistributionChart(buckets: summary.distribution)
        }
    }

    private func parSection(_ summary: StatsSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(String(localized: "stats_section_par"),
                          caption: String(localized: "stats_par_caption"))
            ParPerformanceRow(items: summary.parPerformance)
        }
    }

    /// 평균 타수·평균 오버파의 모집단을 밝힌다 — 9홀 라운드가 빠져 있다는 사실이 드러나야 한다.
    private func fullRoundCaption(_ summary: StatsSummary) -> String {
        String(format: String(localized: "stats_full_round_caption"), summary.fullRoundCount)
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
