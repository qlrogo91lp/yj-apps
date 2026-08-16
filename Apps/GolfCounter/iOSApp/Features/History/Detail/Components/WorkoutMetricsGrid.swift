import SwiftUI

/// 라운드 상세의 워크아웃 요약. 소요 시간은 `endedAt - startedAt`으로 파생한다 (spec §4).
struct WorkoutMetricsGrid: View {
    let round: GolfRound

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "칼로리", value: "\(Int(round.calories.rounded())) kcal")
            StatCard(title: "평균 심박", value: heartRateText)
            StatCard(title: "거리", value: String(format: "%.2f km", round.distanceMeters / 1000))
            StatCard(title: "걸음", value: "\(round.steps)")
            StatCard(title: "소요 시간", value: durationText)
        }
    }

    private var heartRateText: String {
        round.avgHeartRate > 0 ? "\(Int(round.avgHeartRate.rounded())) bpm" : "–"
    }

    private var durationText: String {
        guard let endedAt = round.endedAt else { return "–" }
        let seconds = Int(endedAt.timeIntervalSince(round.startedAt))
        guard seconds > 0 else { return "–" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours)시간 \(minutes)분" : "\(minutes)분"
    }
}
