//
//  iOSApp.swift
//  TennisCounter
//
//  Created by 윤재 on 2023/05/24.
//

import SwiftData
import SwiftUI

@main
struct TennisCounterApp: App {
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([Match.self, SetRecord.self])
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(container)
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            Text("Summary")
                .tabItem {
                    Label(String(localized: "tab_summary"), systemImage: "chart.bar.fill")
                }

            ModeSelectionView()
                .tabItem {
                    Label(String(localized: "tab_match"), systemImage: "sportscourt.fill")
                }

            HistoryView()
                .tabItem {
                    Label(String(localized: "tab_history"), systemImage: "clock.fill")
                }
        }
    }
}

// MARK: - ModeSelection

struct ModeSelectionView: View {
    @StateObject private var viewModel = ModeSelectionViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    Text(String(localized: "new_match"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    ForEach(MatchFormat.allCases, id: \.rawValue) { format in
                        NavigationLink(value: format) {
                            ModeCardView(format: format)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
            }
            .navigationDestination(for: MatchFormat.self) { format in
                MatchView(format: format)
            }
            .navigationBarHidden(true)
        }
    }
}

@MainActor
final class ModeSelectionViewModel: ObservableObject {
    @Published var selectedFormat: MatchFormat?

    func selectFormat(_ format: MatchFormat) {
        selectedFormat = format
    }
}

private struct ModeCardView: View {
    let format: MatchFormat

    private var title: String {
        format == .oneSet ? String(localized: "match_format_one_set") : String(localized: "match_format_best_of_3")
    }

    private var description: String {
        format == .oneSet ? String(localized: "match_format_one_set_desc") : String(localized: "match_format_best_of_3_desc")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(format == .oneSet ? "🎾" : "🏆")
                    .font(.system(size: 28))
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
            }
            Text(description)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(20)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - History

enum HistoryViewMode {
    case list
    case calendar
}

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var viewMode: HistoryViewMode = .list
    @Published var selectedMatch: Match?

    func toggleViewMode() {
        viewMode = viewMode == .list ? .calendar : .list
    }

    func wonMatch(_ match: Match) -> Bool {
        match.myTotalSets > match.yourTotalSets
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func setScore(_ match: Match) -> String {
        "\(match.myTotalSets) - \(match.yourTotalSets)"
    }
}

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

struct MatchRowView: View {
    let match: Match
    let didWin: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(didWin ? Color.green.opacity(0.8) : Color.orange.opacity(0.8))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(didWin ? String(localized: "match_over_win") : String(localized: "match_over_lose"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(didWin ? .green : .orange)

                    Text(formatName(match.matchFormat.rawValue))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }

                Text(formattedDate(match.startedAt))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("\(match.myTotalSets) - \(match.yourTotalSets)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 6)
    }

    private func formatName(_ raw: String) -> String {
        raw == "one_set"
            ? String(localized: "match_format_one_set")
            : String(localized: "match_format_best_of_3")
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

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

struct CalendarHistoryView: View {
    let matches: [Match]
    @Binding var selectedMatch: Match?

    @State private var displayedMonth = Date()

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        VStack(spacing: 0) {
            monthHeader
            weekdayLabels
            daysGrid
        }
    }

    private var monthHeader: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(displayedMonth.formatted(.dateTime.year().month(.wide)))
                .font(.headline)
            Spacer()
            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var weekdayLabels: some View {
        HStack {
            ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 4)
    }

    private var daysGrid: some View {
        let days = daysInMonth()
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(days, id: \.self) { date in
                if let date = date {
                    let dayMatches = matchesForDate(date)
                    DayCellView(date: date, matches: dayMatches) {
                        selectedMatch = dayMatches.first
                    }
                } else {
                    Color.clear
                        .frame(height: 36)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func daysInMonth() -> [Date?] {
        let components = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let firstDay = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)

        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }

    private func matchesForDate(_ date: Date) -> [Match] {
        matches.filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}

private struct DayCellView: View {
    let date: Date
    let matches: [Match]
    let onTap: () -> Void

    private var calendar: Calendar { Calendar.current }
    private var isToday: Bool { calendar.isDateInToday(date) }
    private var hasMatch: Bool { !matches.isEmpty }
    private var hasWin: Bool { matches.contains { $0.myTotalSets > $0.yourTotalSets } }

    var body: some View {
        VStack(spacing: 2) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 14, weight: isToday ? .bold : .regular))
                .foregroundColor(isToday ? .blue : .primary)
                .frame(width: 32, height: 32)
                .background(isToday ? Color.blue.opacity(0.1) : Color.clear)
                .clipShape(Circle())

            if hasMatch {
                Circle()
                    .fill(hasWin ? Color.green : Color.orange)
                    .frame(width: 5, height: 5)
            } else {
                Color.clear.frame(width: 5, height: 5)
            }
        }
        .onTapGesture(perform: onTap)
    }
}
