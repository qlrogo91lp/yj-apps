# iOS Feature 구조 리팩토링 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** iOSApp Feature 폴더를 CLAUDE.md 규칙과 Watch 앱 구조에 맞게 재정비한다.

**Architecture:** God file(`iOSApp.swift`)를 Summary·History·Shared로 분리하고, Match Feature를 Watch 대칭 구조(Mode / Tab / Score / Result / Workout)로 재편한다. 레거시 파일은 삭제한다. 각 Task 완료 시 빌드가 통과해야 하며 Task마다 커밋한다.

**Tech Stack:** Swift, SwiftUI, SwiftData, Xcode 16

> **Xcode 프로젝트 파일:** 이 프로젝트는 `PBXFileSystemSynchronizedRootGroup` 방식(Xcode 16)을 사용한다. 파일을 생성하거나 삭제하면 Xcode가 자동으로 빌드 대상에 포함/제외한다. `.pbxproj` 직접 수정 불필요.

---

## 변경 파일 전체 목록

### 생성
```
iOSApp/Components/MatchDetailSheet.swift
iOSApp/Features/Summary/SummaryView.swift
iOSApp/Features/Summary/SummaryViewModel.swift
iOSApp/Features/Summary/Components/StatCard.swift
iOSApp/Features/Summary/Components/RecentMatchCard.swift
iOSApp/Features/History/HistoryView.swift
iOSApp/Features/History/HistoryViewModel.swift
iOSApp/Features/History/Components/MatchRow.swift
iOSApp/Features/History/Components/CalendarHistoryView.swift
iOSApp/Features/History/Components/DayCell.swift
iOSApp/Features/Match/Mode/ModeView.swift
iOSApp/Features/Match/Mode/Components/ModeCard.swift
iOSApp/Features/Match/Tab/MatchTabView.swift
iOSApp/Features/Match/Tab/MatchTabViewModel.swift
iOSApp/Features/Match/Score/ScoreView.swift
iOSApp/Features/Match/Score/Components/PlayerScoreZone.swift  (이동)
iOSApp/Features/Match/Score/Components/ScoreOverlay.swift     (이동)
iOSApp/Features/Match/Score/Components/ScoreEditSheet.swift   (이동)
iOSApp/Features/Match/Result/MatchResultView.swift
iOSApp/Features/Match/Workout/WorkoutTabView.swift            (이동)
```

### 수정
```
iOSApp/iOSApp.swift          → App entry + MainTabView만 남김
CLAUDE.md                    → iOS 아키텍처 섹션 업데이트
```

### 삭제
```
iOSApp/Features/Match/Score/MatchView.swift              (레거시)
iOSApp/Features/Match/Score/Components/CounterButtonView.swift (레거시)
iOSApp/Features/Match/Score/ModeSelectionView.swift      (→ Mode/ModeView.swift)
iOSApp/Features/Match/Score/ModeSelectionViewModel.swift (미사용)
iOSApp/Features/Match/Session/MatchContainerView.swift   (→ Tab/MatchTabView.swift)
iOSApp/Features/Match/Session/MatchContainerViewModel.swift (→ Tab/MatchTabViewModel.swift)
iOSApp/Features/Match/Session/Score/ScoreTabView.swift   (→ Score/ScoreView.swift)
iOSApp/Features/Match/Session/Score/Components/PlayerScoreZone.swift (이동)
iOSApp/Features/Match/Session/Score/Components/ScoreOverlay.swift    (이동)
iOSApp/Features/Match/Session/Score/Components/ScoreEditSheet.swift  (이동)
iOSApp/Features/Match/Session/Workout/WorkoutTabView.swift           (이동)
```

---

## Task 1: 레거시 파일 삭제

**Files:**
- Delete: `iOSApp/Features/Match/Score/MatchView.swift`
- Delete: `iOSApp/Features/Match/Score/Components/CounterButtonView.swift`
- Delete: `iOSApp/Features/Match/Score/ModeSelectionViewModel.swift`
- Modify: `iOSApp/Features/Match/Score/ModeSelectionView.swift`

- [ ] **Step 1: 레거시 Swift 파일 삭제**

```bash
git rm iOSApp/Features/Match/Score/MatchView.swift
git rm iOSApp/Features/Match/Score/Components/CounterButtonView.swift
git rm iOSApp/Features/Match/Score/ModeSelectionViewModel.swift
```

- [ ] **Step 2: ModeSelectionView에서 미사용 ViewModel 참조 제거**

`iOSApp/Features/Match/Score/ModeSelectionView.swift` 수정 — `@StateObject private var viewModel = ModeSelectionViewModel()` 줄 삭제:

```swift
import SwiftUI

struct ModeSelectionView: View {
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
                MatchContainerView(format: format)
                    .toolbar(.hidden, for: .tabBar)
            }
            .navigationBarHidden(true)
        }
    }
}

private struct ModeCardView: View {
    let format: MatchFormat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(format == .oneSet ? "🎾" : "🏆")
                    .font(.system(size: 28))
                Text(format.localizedTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
            }
            Text(format.localizedDescription)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(20)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

- [ ] **Step 3: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 커밋**

```bash
git add iOSApp/Features/Match/Score/ModeSelectionView.swift
git commit -m "refactor: 레거시 파일 삭제 (MatchView, CounterButtonView, ModeSelectionViewModel)"
```

---

## Task 2: Summary Feature 분리

**Files:**
- Create: `iOSApp/Features/Summary/SummaryViewModel.swift`
- Create: `iOSApp/Features/Summary/SummaryView.swift`
- Create: `iOSApp/Features/Summary/Components/StatCard.swift`
- Create: `iOSApp/Features/Summary/Components/RecentMatchCard.swift`
- Modify: `iOSApp/iOSApp.swift`

- [ ] **Step 1: SummaryViewModel.swift 생성**

`iOSApp/Features/Summary/SummaryViewModel.swift`:

```swift
import Foundation

enum SummaryPeriod: String, CaseIterable {
    case today, week, month, all

    var localizedTitle: String {
        switch self {
        case .today: String(localized: "summary_period_today")
        case .week: String(localized: "summary_period_week")
        case .month: String(localized: "summary_period_month")
        case .all: String(localized: "summary_period_all")
        }
    }

    func startDate(from now: Date = Date()) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .today: return calendar.startOfDay(for: now)
        case .week: return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
        case .month:
            let components = calendar.dateComponents([.year, .month], from: now)
            return calendar.date(from: components)
        case .all: return nil
        }
    }
}

struct SummaryStats {
    let totalMatches: Int
    let wins: Int
    let winRate: Double
    let streak: Int
}

@MainActor
final class SummaryViewModel: ObservableObject {
    @Published var selectedPeriod: SummaryPeriod = .week
    @Published var selectedMatch: Match?

    func stats(from matches: [Match]) -> SummaryStats {
        let filtered = filteredMatches(from: matches)
        let wins = filtered.count(where: { $0.myTotalSets > $0.yourTotalSets })
        let total = filtered.count
        let winRate = total > 0 ? Double(wins) / Double(total) : 0.0
        return SummaryStats(totalMatches: total, wins: wins, winRate: winRate, streak: calculateStreak(from: matches))
    }

    func recentMatches(from matches: [Match]) -> [Match] {
        Array(matches.prefix(2))
    }

    func filteredMatches(from matches: [Match]) -> [Match] {
        guard let start = selectedPeriod.startDate() else { return matches }
        return matches.filter { $0.startedAt >= start }
    }

    private func calculateStreak(from matches: [Match]) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = Date()
        for match in matches {
            let matchDay = calendar.startOfDay(for: match.startedAt)
            let currentDay = calendar.startOfDay(for: checkDate)
            let diff = calendar.dateComponents([.day], from: matchDay, to: currentDay).day ?? 0
            if diff == 0 || diff == streak {
                streak = max(streak, diff + 1)
                checkDate = match.startedAt
            } else {
                break
            }
        }
        return streak
    }
}
```

- [ ] **Step 2: SummaryView.swift 생성**

`iOSApp/Features/Summary/SummaryView.swift`:

```swift
import SwiftData
import SwiftUI

struct SummaryView: View {
    @StateObject private var viewModel = SummaryViewModel()
    @Query(sort: \Match.startedAt, order: .reverse) private var matches: [Match]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    periodPicker
                    statsGrid
                    recentMatchesSection
                }
                .padding()
            }
            .navigationTitle(String(localized: "tab_summary"))
            .sheet(item: $viewModel.selectedMatch) { match in
                MatchDetailSheet(match: match)
            }
        }
    }

    private var periodPicker: some View {
        Picker("Period", selection: $viewModel.selectedPeriod) {
            ForEach(SummaryPeriod.allCases, id: \.rawValue) { period in
                Text(period.localizedTitle).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    private var statsGrid: some View {
        let stats = viewModel.stats(from: matches)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(title: String(localized: "summary_total_matches"), value: "\(stats.totalMatches)", systemImage: "sportscourt.fill", color: .blue)
            StatCard(title: String(localized: "summary_win_rate"), value: String(format: "%.0f%%", stats.winRate * 100), systemImage: "trophy.fill", color: stats.winRate >= 0.5 ? .green : .orange)
            StatCard(title: String(localized: "summary_streak"), value: "\(stats.streak)", systemImage: "flame.fill", color: .red)
            StatCard(title: "Wins", value: "\(stats.wins)", systemImage: "checkmark.circle.fill", color: .green)
        }
    }

    private var recentMatchesSection: some View {
        let recent = viewModel.recentMatches(from: matches)
        return Group {
            if !recent.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "summary_recent_matches"))
                        .font(.headline)
                    ForEach(recent) { match in
                        RecentMatchCard(match: match)
                            .onTapGesture { viewModel.selectedMatch = match }
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 3: StatCard.swift 생성**

`iOSApp/Features/Summary/Components/StatCard.swift`:

```swift
import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

- [ ] **Step 4: RecentMatchCard.swift 생성**

`iOSApp/Features/Summary/Components/RecentMatchCard.swift`:

```swift
import SwiftUI

struct RecentMatchCard: View {
    let match: Match

    private var didWin: Bool { match.myTotalSets > match.yourTotalSets }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(didWin ? String(localized: "match_over_win") : String(localized: "match_over_lose"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(didWin ? .green : .orange)
                    Text(match.matchFormat == .oneSet
                        ? String(localized: "match_format_one_set")
                        : String(localized: "match_format_best_of_3"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(match.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(match.myTotalSets) – \(match.yourTotalSets)")
                .font(.system(size: 22, weight: .bold))
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
```

- [ ] **Step 5: iOSApp.swift에서 Summary 관련 타입 제거**

`iOSApp/iOSApp.swift`에서 `// MARK: - Summary` 블록 전체(SummaryPeriod, SummaryStats, SummaryViewModel, SummaryView, SummaryStatCard, SummaryRecentMatchCard) 삭제. 파일이 아래 내용만 남도록 한다:

```swift
import SwiftData
import SwiftUI

@main
struct TennisCounterApp: App {
    let container: ModelContainer
    private let watchConnectivity = WatchConnectivityService.shared

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
            SummaryView()
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

// MARK: - History
// (History 타입들은 아직 여기 있음 — Task 3에서 분리)
```

> **Note:** iOSApp.swift에는 아직 History 관련 타입이 남아있다. Task 3에서 분리한다.

- [ ] **Step 7: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: 커밋**

```bash
git add iOSApp/Features/Summary/ iOSApp/iOSApp.swift TennisCounter.xcodeproj
git commit -m "refactor: Summary Feature를 별도 파일로 분리"
```

---

## Task 3: History Feature + Shared 분리

**Files:**
- Create: `iOSApp/Components/MatchDetailSheet.swift`
- Create: `iOSApp/Features/History/HistoryViewModel.swift`
- Create: `iOSApp/Features/History/HistoryView.swift`
- Create: `iOSApp/Features/History/Components/MatchRow.swift`
- Create: `iOSApp/Features/History/Components/CalendarHistoryView.swift`
- Create: `iOSApp/Features/History/Components/DayCell.swift`
- Modify: `iOSApp/iOSApp.swift` (History 타입 전부 제거, MainTabView만 남김)

- [ ] **Step 1: MatchDetailSheet.swift 생성 (앱 루트 공유 컴포넌트)**

`iOSApp/Components/MatchDetailSheet.swift`:

```swift
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
                        Text("No set data").foregroundColor(.secondary)
                    } else {
                        ForEach(sets, id: \.setNumber) { set in
                            HStack {
                                Text("Set \(set.setNumber)").foregroundColor(.secondary)
                                Spacer()
                                Text("\(set.myGames)")
                                    .font(.system(size: 18, weight: .bold)).foregroundColor(.green)
                                Text(" – ").foregroundColor(.secondary)
                                Text("\(set.yourGames)")
                                    .font(.system(size: 18, weight: .bold)).foregroundColor(.orange)
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
```

- [ ] **Step 2: HistoryViewModel.swift 생성**

`iOSApp/Features/History/HistoryViewModel.swift`:

```swift
import Foundation

enum HistoryViewMode {
    case list
    case calendar
}

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var viewMode: HistoryViewMode = .list

    func toggleViewMode() {
        viewMode = viewMode == .list ? .calendar : .list
    }

    func wonMatch(_ match: Match) -> Bool {
        match.myTotalSets > match.yourTotalSets
    }
}
```

- [ ] **Step 3: HistoryView.swift 생성**

`iOSApp/Features/History/HistoryView.swift`:

```swift
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
                MatchRow(match: match, didWin: viewModel.wonMatch(match))
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
```

- [ ] **Step 4: MatchRow.swift 생성**

`iOSApp/Features/History/Components/MatchRow.swift`:

```swift
import SwiftUI

struct MatchRow: View {
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
```

- [ ] **Step 5: DayCell.swift 생성**

`iOSApp/Features/History/Components/DayCell.swift`:

```swift
import SwiftUI

struct DayCell: View {
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
```

- [ ] **Step 6: CalendarHistoryView.swift 생성**

`iOSApp/Features/History/Components/CalendarHistoryView.swift`:

```swift
import SwiftUI

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
                if let date {
                    let dayMatches = matchesForDate(date)
                    DayCell(date: date, matches: dayMatches) {
                        selectedMatch = dayMatches.first
                    }
                } else {
                    Color.clear.frame(height: 36)
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
```

- [ ] **Step 7: iOSApp.swift를 최종 형태로 정리**

`iOSApp/iOSApp.swift` 전체를 아래 내용으로 교체한다 (History 타입 전부 제거):

```swift
import SwiftData
import SwiftUI

@main
struct TennisCounterApp: App {
    let container: ModelContainer
    private let watchConnectivity = WatchConnectivityService.shared

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
            SummaryView()
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
```

- [ ] **Step 8: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: 커밋**

```bash
git add iOSApp/Components/ iOSApp/Features/History/ iOSApp/iOSApp.swift
git commit -m "refactor: History Feature + MatchDetailSheet 분리, iOSApp.swift 정리"
```

---

## Task 4: Match/Mode 구조 생성

**Files:**
- Create: `iOSApp/Features/Match/Mode/ModeView.swift`
- Create: `iOSApp/Features/Match/Mode/Components/ModeCard.swift`

> ModeSelectionView.swift 삭제는 Task 7에서 한다 (빌드 순서 보장).

- [ ] **Step 1: ModeCard.swift 생성**

`iOSApp/Features/Match/Mode/Components/ModeCard.swift`:

```swift
import SwiftUI

struct ModeCard: View {
    let format: MatchFormat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(format == .oneSet ? "🎾" : "🏆")
                    .font(.system(size: 28))
                Text(format.localizedTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
            }
            Text(format.localizedDescription)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(20)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

- [ ] **Step 2: ModeView.swift 생성**

`iOSApp/Features/Match/Mode/ModeView.swift`:

```swift
import SwiftUI

struct ModeView: View {
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
                            ModeCard(format: format)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
            }
            .navigationDestination(for: MatchFormat.self) { format in
                MatchTabView(format: format)
                    .toolbar(.hidden, for: .tabBar)
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    ModeView()
}
```

> **Note:** ModeView가 `MatchTabView`를 참조하지만 Task 5 전까지는 해당 타입이 없다. Task 5 이후 빌드를 확인한다.

---

## Task 5: Match/Tab + Match/Workout 구조 생성

**Files:**
- Create: `iOSApp/Features/Match/Tab/MatchTabView.swift`
- Create: `iOSApp/Features/Match/Tab/MatchTabViewModel.swift`
- Create: `iOSApp/Features/Match/Workout/WorkoutTabView.swift`

> ScoreTabView가 아직 Session/Score/에 있으므로 `ScoreTabView` 타입명으로 참조한다. Task 6에서 ScoreView로 교체한다.

- [ ] **Step 1: MatchTabViewModel.swift 생성**

`iOSApp/Features/Match/Tab/MatchTabViewModel.swift`:

```swift
import Combine
import Foundation

@MainActor
final class MatchTabViewModel: ObservableObject {
    @Published var watchConnected: Bool = false
    @Published var metrics: WorkoutMetrics = .init()

    init() {
        let service = WatchConnectivityService.shared

        service.$isWatchReachable
            .receive(on: DispatchQueue.main)
            .assign(to: &$watchConnected)

        service.$receivedMetrics
            .receive(on: DispatchQueue.main)
            .compactMap(\.self)
            .assign(to: &$metrics)
    }
}
```

- [ ] **Step 2: MatchTabView.swift 생성**

`iOSApp/Features/Match/Tab/MatchTabView.swift`:

```swift
import SwiftUI

struct MatchTabView: View {
    let format: MatchFormat

    @StateObject private var viewModel = MatchTabViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: Int = 1

    var body: some View {
        TabView(selection: $selectedTab) {
            if viewModel.watchConnected {
                WorkoutTabView(
                    metrics: viewModel.metrics,
                    onPauseResume: {},
                    onEnd: { dismiss() }
                )
                .tabItem {
                    Label(String(localized: "tab_workout"), systemImage: "figure.run")
                }
                .tag(0)
            }

            ScoreTabView(format: format)
                .tabItem {
                    Label(String(localized: "tab_match"), systemImage: "sportscourt.fill")
                }
                .tag(1)
        }
        .preferredColorScheme(.dark)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        MatchTabView(format: .bestOfThree)
    }
}
```

- [ ] **Step 3: Match/Workout/WorkoutTabView.swift 생성 (Session/Workout에서 이동)**

`iOSApp/Features/Match/Workout/WorkoutTabView.swift` — `iOSApp/Features/Match/Session/Workout/WorkoutTabView.swift`와 동일한 내용:

```swift
import SwiftUI

struct WorkoutTabView: View {
    let metrics: WorkoutMetrics
    let onPauseResume: () -> Void
    let onEnd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            metricsList
            Spacer()
            controlButtons
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.black.ignoresSafeArea())
    }

    private var metricsList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(metrics.formattedElapsed)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.yellow)
                .contentTransition(.numericText())

            HStack(alignment: .bottom, spacing: 6) {
                Text(String(format: "%.0f", metrics.calories))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                Text("kcal")
                    .font(.system(size: 20, weight: .semibold))
                    .padding(.bottom, 4)
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .bottom, spacing: 6) {
                Text(metrics.heartRate > 0 ? String(format: "%.0f", metrics.heartRate) : "--")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                Image(systemName: metrics.heartRate > 0 ? "heart.fill" : "heart")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
                    .padding(.bottom, 4)
            }
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 12) {
            Button(action: onPauseResume) {
                Label(String(localized: "workout_pause"), systemImage: "pause.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(.yellow)

            Button(role: .destructive, action: onEnd) {
                Label(String(localized: "workout_end"), systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        }
    }
}

#Preview {
    WorkoutTabView(
        metrics: WorkoutMetrics(elapsedSeconds: 1523, calories: 245, heartRate: 102),
        onPauseResume: {},
        onEnd: {}
    )
}
```

- [ ] **Step 5: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: 커밋**

```bash
git add iOSApp/Features/Match/Mode/ iOSApp/Features/Match/Tab/ iOSApp/Features/Match/Workout/ TennisCounter.xcodeproj
git commit -m "refactor: Match/Mode, Match/Tab, Match/Workout 신규 구조 생성"
```

---

## Task 6: Match/Score + Match/Result 구조 생성

**Files:**
- Create: `iOSApp/Features/Match/Result/MatchResultView.swift`
- Create: `iOSApp/Features/Match/Score/ScoreView.swift`
- Create: `iOSApp/Features/Match/Score/Components/PlayerScoreZone.swift` (이동)
- Create: `iOSApp/Features/Match/Score/Components/ScoreOverlay.swift` (이동)
- Create: `iOSApp/Features/Match/Score/Components/ScoreEditSheet.swift` (이동)
- Modify: `iOSApp/Features/Match/Tab/MatchTabView.swift` (`ScoreTabView` → `ScoreView`)

- [ ] **Step 1: MatchResultView.swift 생성**

`iOSApp/Features/Match/Result/MatchResultView.swift`:

```swift
import SwiftUI

struct MatchResultView: View {
    let didWin: Bool
    let completedSets: [(my: Int, your: Int)]
    let onNewMatch: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text(didWin ? String(localized: "match_over_win") : String(localized: "match_over_lose"))
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(didWin ? .green : .orange)

            HStack(spacing: 24) {
                ForEach(completedSets.indices, id: \.self) { idx in
                    let set = completedSets[idx]
                    VStack(spacing: 2) {
                        Text("Set \(idx + 1)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                        HStack(spacing: 4) {
                            Text("\(set.my)").foregroundColor(.green)
                            Text("–").foregroundColor(.white.opacity(0.5))
                            Text("\(set.your)").foregroundColor(.orange)
                        }
                        .font(.system(size: 18, weight: .bold))
                    }
                }
            }

            Button(action: onNewMatch) {
                Text(String(localized: "btn_new_match"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

#Preview {
    MatchResultView(
        didWin: true,
        completedSets: [(my: 6, your: 4), (my: 6, your: 3)],
        onNewMatch: {}
    )
}
```

- [ ] **Step 2: ScoreView.swift 생성**

`iOSApp/Features/Match/Score/ScoreView.swift`:

```swift
import SwiftData
import SwiftUI

struct ScoreView: View {
    let format: MatchFormat

    @StateObject private var viewModel: MatchViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet = false
    @State private var showEarlyEndConfirm = false

    init(format: MatchFormat) {
        self.format = format
        _viewModel = StateObject(wrappedValue: MatchViewModel(format: format))
    }

    var body: some View {
        Group {
            if viewModel.isMatchOver {
                MatchResultView(
                    didWin: viewModel.didWin,
                    completedSets: viewModel.completedSets,
                    onNewMatch: {
                        viewModel.resetAll()
                        dismiss()
                    }
                )
            } else {
                scoreView
            }
        }
        .onAppear { viewModel.injectContext(modelContext) }
        .sheet(isPresented: $showEditSheet) {
            ScoreEditSheet(score: viewModel.score)
        }
        .confirmationDialog(
            String(localized: "early_end_confirm_title"),
            isPresented: $showEarlyEndConfirm
        ) {
            Button(String(localized: "early_end_confirm_yes"), role: .destructive) {
                dismiss()
            }
        } message: {
            Text(String(localized: "early_end_confirm_message"))
        }
    }

    private var scoreView: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            HStack(spacing: 0) {
                PlayerScoreZone(
                    displayScore: viewModel.score.myDisplayScore,
                    playerLabel: String(localized: "watch_score_me"),
                    color: .green,
                    onTap: { withAnimation { viewModel.addPoint(.me) } },
                    onLongPress: { showEditSheet = true }
                )
                PlayerScoreZone(
                    displayScore: viewModel.score.yourDisplayScore,
                    playerLabel: String(localized: "watch_score_opp"),
                    color: .orange,
                    onTap: { withAnimation { viewModel.addPoint(.opponent) } },
                    onLongPress: { showEditSheet = true }
                )
            }
            .ignoresSafeArea()

            ScoreOverlay(
                myGameScore: viewModel.myGameScore,
                yourGameScore: viewModel.yourGameScore,
                mySetScore: viewModel.mySetScore,
                yourSetScore: viewModel.yourSetScore,
                format: format,
                showUndo: viewModel.score.lastAction != .none,
                onUndo: { viewModel.undo() }
            )
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "early_end_button")) {
                    showEarlyEndConfirm = true
                }
                .font(.system(size: 14))
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }
}
```

- [ ] **Step 3: Score/Components 파일 3개 생성 (Session/Score/Components에서 이동)**

파일 내용은 기존과 동일하다. 아래 경로에 각각 생성한다.

`iOSApp/Features/Match/Score/Components/PlayerScoreZone.swift` — `iOSApp/Features/Match/Session/Score/Components/PlayerScoreZone.swift`와 동일한 내용 복사.

`iOSApp/Features/Match/Score/Components/ScoreOverlay.swift` — `iOSApp/Features/Match/Session/Score/Components/ScoreOverlay.swift`와 동일한 내용 복사.

`iOSApp/Features/Match/Score/Components/ScoreEditSheet.swift` — `iOSApp/Features/Match/Session/Score/Components/ScoreEditSheet.swift`와 동일한 내용 복사.

```bash
cp iOSApp/Features/Match/Session/Score/Components/PlayerScoreZone.swift \
   iOSApp/Features/Match/Score/Components/PlayerScoreZone.swift

cp iOSApp/Features/Match/Session/Score/Components/ScoreOverlay.swift \
   iOSApp/Features/Match/Score/Components/ScoreOverlay.swift

cp iOSApp/Features/Match/Session/Score/Components/ScoreEditSheet.swift \
   iOSApp/Features/Match/Score/Components/ScoreEditSheet.swift
```

> **중요:** 아직 Session/Score/Components/의 원본은 삭제하지 않는다. 삭제는 Task 7에서 한다. Swift는 같은 타입 두 개가 같은 모듈에 있으면 컴파일 에러가 나므로 Task 7에서 즉시 삭제한다.

- [ ] **Step 4: MatchTabView에서 ScoreTabView → ScoreView로 교체**

`iOSApp/Features/Match/Tab/MatchTabView.swift`의 `ScoreTabView(format: format)` → `ScoreView(format: format)`:

```swift
            ScoreView(format: format)
                .tabItem {
                    Label(String(localized: "tab_match"), systemImage: "sportscourt.fill")
                }
                .tag(1)
```

---

## Task 7: 구 파일 전체 삭제 + 빌드 확인

**Files:** Session/ 폴더 전체 및 ModeSelectionView 삭제

- [ ] **Step 1: 구 Session/ 파일 삭제 (중복 타입 제거)**

```bash
git rm iOSApp/Features/Match/Session/Score/Components/PlayerScoreZone.swift
git rm iOSApp/Features/Match/Session/Score/Components/ScoreOverlay.swift
git rm iOSApp/Features/Match/Session/Score/Components/ScoreEditSheet.swift
git rm iOSApp/Features/Match/Session/Score/ScoreTabView.swift
git rm iOSApp/Features/Match/Session/Workout/WorkoutTabView.swift
git rm iOSApp/Features/Match/Session/MatchContainerView.swift
git rm iOSApp/Features/Match/Session/MatchContainerViewModel.swift
git rm iOSApp/Features/Match/Score/ModeSelectionView.swift
```

- [ ] **Step 2: iOSApp.swift의 MainTabView에서 ModeSelectionView → ModeView 교체**

`iOSApp/iOSApp.swift`의 MainTabView:

```swift
            ModeView()
                .tabItem {
                    Label(String(localized: "tab_match"), systemImage: "sportscourt.fill")
                }
```

- [ ] **Step 4: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: 커밋**

```bash
git add iOSApp/Features/Match/ iOSApp/iOSApp.swift
git commit -m "refactor: Match Feature 재구조화 완료 (Mode/Tab/Score/Result/Workout)"
```

---

## Task 8: CLAUDE.md 아키텍처 업데이트 + 최종 커밋

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: CLAUDE.md의 iOS 아키텍처 섹션 업데이트**

`CLAUDE.md`의 `iOSApp/` 트리 블록을 아래 내용으로 교체한다:

```
iOSApp/
│  # iPhone 전용 타겟
├── iOSApp.swift           # @main 진입점 + MainTabView
├── Components/
│   └── MatchDetailSheet.swift  # Summary·History 공유 컴포넌트
└── Features/
    ├── Summary/
    │   ├── SummaryView.swift
    │   ├── SummaryViewModel.swift  # SummaryPeriod, SummaryStats 포함
    │   └── Components/
    │       ├── StatCard.swift
    │       └── RecentMatchCard.swift
    ├── Match/
    │   │  # Watch 앱과 대칭 구조: Mode / Tab(iOS 전용) / Score / Result / Workout
    │   ├── Mode/                        # 포맷 선택 화면 (Watch: Match/Mode/)
    │   │   ├── ModeView.swift
    │   │   └── Components/
    │   │       └── ModeCard.swift
    │   ├── Tab/                         # iOS 전용 탭 컨테이너 (Watch: WorkoutSession/)
    │   │   ├── MatchTabView.swift
    │   │   └── MatchTabViewModel.swift
    │   ├── Score/                       # 점수 입력 화면 (Watch: Match/Score/)
    │   │   ├── ScoreView.swift
    │   │   ├── MatchViewModel.swift
    │   │   └── Components/
    │   │       ├── PlayerScoreZone.swift
    │   │       ├── ScoreOverlay.swift
    │   │       └── ScoreEditSheet.swift
    │   ├── Result/                      # 경기 결과 화면 (Watch: Match/Result/)
    │   │   └── MatchResultView.swift
    │   └── Workout/                     # 워크아웃 메트릭 탭 (iOS 전용)
    │       └── WorkoutTabView.swift
    └── History/
        ├── HistoryView.swift
        ├── HistoryViewModel.swift
        └── Components/
            ├── MatchRow.swift
            ├── CalendarHistoryView.swift
            └── DayCell.swift
```

- [ ] **Step 2: Watch 앱 비교 표 확인**

CLAUDE.md의 Score 섹션에 아래 ViewModel 설명 업데이트:

```
- **MatchViewModel**: `Score` 인스턴스를 `@Published`로 소유, 게임/세트 레벨 로직 담당. `Match/Score/MatchViewModel.swift`에 위치.
- **ScoreView**: `@StateObject var viewModel = MatchViewModel()`으로 ViewModel 바인딩. 경기 종료 시 `MatchResultView`로 전환.
```

- [ ] **Step 3: 최종 빌드 + Watch 앱 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"

xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: 두 타겟 모두 `** BUILD SUCCEEDED **`

- [ ] **Step 4: 최종 커밋**

```bash
git add CLAUDE.md
git commit -m "docs: CLAUDE.md iOS 아키텍처 섹션 업데이트 (리팩토링 완료 반영)"
```
