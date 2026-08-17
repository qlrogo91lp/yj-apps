import Charts
import SwiftUI

/// 집계 대상 홀 전체를 버디 이상 / 파 / 보기 / 더블보기+ 로 나눈 가로 막대 (spec §5).
struct ScoreDistributionChart: View {
    let buckets: [StatsSummary.BucketCount]

    var body: some View {
        Chart(buckets) { bucket in
            BarMark(x: .value(String(localized: "chart_axis_holes"), bucket.count),
                    y: .value(String(localized: "chart_axis_bucket"), Self.title(for: bucket.bucket)))
                .foregroundStyle(Color.accentColor)
                .annotation(position: .trailing) {
                    Text(String(format: String(localized: "chart_bucket_value"),
                                bucket.count, Self.percent(bucket.ratio)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
        }
        // 축이 알파벳 순으로 재배열되지 않게 순서를 고정한다.
        .chartYScale(domain: StatsSummary.Bucket.allCases.map(Self.title(for:)))
        .chartXAxis(.hidden)
        .frame(height: 180)
    }

    private static func title(for bucket: StatsSummary.Bucket) -> String {
        switch bucket {
        case .birdieOrBetter: String(localized: "bucket_birdie_or_better")
        case .par: String(localized: "bucket_par")
        case .bogey: String(localized: "bucket_bogey")
        case .doubleOrWorse: String(localized: "bucket_double_or_worse")
        }
    }

    private static func percent(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }
}

#Preview {
    ScoreDistributionChart(buckets: [
        StatsSummary.BucketCount(bucket: .birdieOrBetter, count: 2, ratio: 0.05),
        StatsSummary.BucketCount(bucket: .par, count: 10, ratio: 0.28),
        StatsSummary.BucketCount(bucket: .bogey, count: 16, ratio: 0.44),
        StatsSummary.BucketCount(bucket: .doubleOrWorse, count: 8, ratio: 0.23),
    ])
    .padding()
}
