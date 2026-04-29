import SwiftData
import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()
    @Query(sort: \Match.startedAt, order: .reverse) private var matches: [Match]
    @State private var selectedMatch: Match?

    var body: some View {
        NavigationStack {
            Group {
                if matches.isEmpty {
                    emptyState
                } else if viewModel.viewMode == .list {
                    listView
                } else {
                    calendarView
                }
            }
            .navigationTitle(String(localized: "history_title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { viewModel.toggleViewMode() }) {
                        Image(systemName: viewModel.viewMode == .list ? "calendar" : "list.bullet")
                    }
                }
            }
            .sheet(item: $selectedMatch) { match in
                MatchDetailSheet(match: match)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.xmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(String(localized: "history_empty"))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listView: some View {
        List {
            ForEach(matches) { match in
                MatchRowView(match: match, didWin: viewModel.wonMatch(match))
                    .contentShape(Rectangle())
                    .onTapGesture { selectedMatch = match }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .listStyle(.plain)
    }

    private var calendarView: some View {
        ScrollView {
            CalendarHistoryView(matches: matches, selectedMatch: $selectedMatch)
                .padding()
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}
