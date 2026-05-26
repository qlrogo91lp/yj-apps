import SwiftUI

struct MatchDetailSheet: View {
    let match: Match

    @Environment(\.dismiss) private var dismiss

    private var matchDurationString: String {
        if let d = match.durationSeconds {
            return WorkoutMetrics.formatSeconds(d)
        }
        if let end = match.endedAt {
            return WorkoutMetrics.formatSeconds(Int(end.timeIntervalSince(match.startedAt)))
        }
        return "–"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Text(match.myTotalSets > match.yourTotalSets
                                ? String(localized: "match_over_win")
                                : String(localized: "match_over_lose"))
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(match.myTotalSets > match.yourTotalSets ? .green : .orange)

                            Text("\(match.myTotalSets) – \(match.yourTotalSets)")
                                .font(.system(size: 22, weight: .semibold))
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section(header: Text(String(localized: "summary_section_workout"))) {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 12
                    ) {
                        StatCard(
                            title: String(localized: "summary_total_calories"),
                            value: match.caloriesBurned.map { String(format: "%.0f", $0) } ?? "–",
                            color: .white
                        )
                        StatCard(
                            title: String(localized: "summary_duration"),
                            value: matchDurationString,
                            color: .white
                        )
                        StatCard(
                            title: String(localized: "summary_avg_heartrate"),
                            value: match.averageHeartRate.map { String(format: "%.0f", $0) } ?? "–",
                            color: .white
                        )
                    }
                    .padding(.horizontal, 8)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section(header: Text(String(localized: "match_detail_section_sets"))) {
                    let sets = (match.sets ?? []).sorted { $0.setNumber < $1.setNumber }
                    if sets.isEmpty {
                        Text("No set data").foregroundColor(.secondary)
                    } else {
                        ForEach(sets, id: \.setNumber) { set in
                            HStack {
                                Text("Set \(set.setNumber)").foregroundColor(.secondary)
                                Spacer()
                                Text("\(set.myGames)")
                                    .font(.system(size: 18, weight: .bold)).foregroundColor(.green)
                                Text(":").foregroundColor(.secondary)
                                Text("\(set.yourGames)")
                                    .font(.system(size: 18, weight: .bold)).foregroundColor(.orange)
                            }
                            .padding(.horizontal, 6)
                        }
                    }
                }

                Section(header: Text(String(localized: "match_detail_section_info"))) {
                    LabeledContent("Format") {
                        Text(match.matchFormat == .oneSet
                            ? String(localized: "match_format_one_set")
                            : String(localized: "match_format_best_of_3"))
                    }
                    LabeledContent("Date") {
                        Text(match.startedAt.formatted(date: .abbreviated, time: .shortened))
                    }
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
