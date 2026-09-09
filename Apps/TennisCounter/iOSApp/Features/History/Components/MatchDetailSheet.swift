import SwiftUI
import WorkoutCore

struct MatchDetailSheet: View {
    let match: Match

    @Environment(\.dismiss) private var dismiss

    /// 경기 구간 값이라 스톱워치 포맷을 그대로 쓴다 — 여기는 누적이 아니다.
    private var matchDurationString: String {
        if let d = match.durationSeconds {
            return WorkoutMetrics.formatSeconds(d)
        }
        if let end = match.endedAt {
            return WorkoutMetrics.formatSeconds(Int(end.timeIntervalSince(match.startedAt)))
        }
        return "–"
    }

    /// "14:30 ~ 15:22". 끝난 시각이 없으면 시작 시각만.
    private var timeRangeString: String {
        let start = match.startedAt.formatted(date: .abbreviated, time: .shortened)
        guard let end = match.endedAt else { return start }
        return "\(start) ~ \(end.formatted(date: .omitted, time: .shortened))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Scoreboard(match: match)
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                }

                // 4칸 전부 경기 구간값이다. 세션 누적과 구분하려고 제목을 "이 경기"로 둔다.
                Section(header: Text(String(localized: "match_detail_section_this_match"))) {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 12
                    ) {
                        StatCard(
                            title: String(localized: "summary_total_calories"),
                            value: match.caloriesBurned.map { String(format: "%.0f", $0) } ?? "–"
                        )
                        StatCard(
                            title: String(localized: "summary_total_energy"),
                            value: match.totalCaloriesBurned.map { String(format: "%.0f", $0) } ?? "–"
                        )
                        StatCard(
                            title: String(localized: "summary_duration"),
                            value: matchDurationString
                        )
                        StatCard(
                            title: String(localized: "summary_avg_heartrate"),
                            value: match.averageHeartRate.map { String(format: "%.0f", $0) } ?? "–"
                        )
                    }
                    .padding(.horizontal, 8)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section(header: Text(String(localized: "match_detail_section_info"))) {
                    LabeledContent(String(localized: "match_detail_format")) {
                        Text(match.matchFormat == .oneSet
                            ? String(localized: "match_format_one_set")
                            : String(localized: "match_format_best_of_3"))
                    }
                    LabeledContent(String(localized: "match_detail_time")) {
                        Text(timeRangeString)
                    }
                }

                Section {
                    MatchShareButton(match: match)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(String(localized: "match_detail_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "btn_cancel")) { dismiss() }
                }
            }
        }
    }
}

#Preview {
    let match = Match()
    match.startedAt = Date()
    match.endedAt = Date().addingTimeInterval(3120)
    match.myTotalSets = 2
    match.yourTotalSets = 1
    match.caloriesBurned = 320
    match.totalCaloriesBurned = 410
    match.durationSeconds = 5400
    match.averageHeartRate = 132
    match.workoutElapsedSeconds = 5400
    match.workoutCaloriesBurned = 320
    match.workoutTotalCaloriesBurned = 410
    match.sets = [
        SetRecord(myGames: 6, yourGames: 4, setNumber: 1),
        SetRecord(myGames: 4, yourGames: 6, setNumber: 2),
        SetRecord(myGames: 6, yourGames: 3, setNumber: 3),
    ]

    return MatchDetailSheet(match: match)
}
