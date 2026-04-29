import SwiftUI

struct MatchDetailSheet: View {
    let match: Match

    @Environment(\.dismiss) private var dismiss

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

                Section(header: Text("Sets")) {
                    let sets = (match.sets ?? []).sorted { $0.setNumber < $1.setNumber }
                    if sets.isEmpty {
                        Text("No set data")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(sets, id: \.setNumber) { set in
                            HStack {
                                Text("Set \(set.setNumber)")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(set.myGames)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.green)
                                Text(" – ")
                                    .foregroundColor(.secondary)
                                Text("\(set.yourGames)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }

                Section(header: Text("Info")) {
                    LabeledContent("Format") {
                        Text(match.matchFormat == .oneSet
                             ? String(localized: "match_format_one_set")
                             : String(localized: "match_format_best_of_3"))
                    }
                    if let endedAt = match.endedAt {
                        LabeledContent("Duration") {
                            let minutes = Int(endedAt.timeIntervalSince(match.startedAt) / 60)
                            Text("\(minutes) min")
                        }
                    }
                    LabeledContent("Date") {
                        Text(match.startedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
            .navigationTitle("Match Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "btn_cancel")) { dismiss() }
                }
            }
        }
    }
}
