# Summary & History 개선 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Summary 화면에 피트니스 섹션 추가, MatchDetailSheet에 Workout 카드 섹션 추가, CalendarHistoryView 탭 동작 수정.

**Architecture:** SummaryStats struct에 피트니스 집계 필드를 추가하고, WorkoutMetrics에 Int 초 단위 포맷 helper를 공유 static으로 추출. View는 ViewModel이 계산한 값을 그대로 표시.

**Tech Stack:** SwiftUI, SwiftData, Swift Testing

---

## 변경 파일 목록

| 파일 | 역할 |
|------|------|
| `Shared/Models/WorkoutMetrics.swift` | `static func formatSeconds(_:)` 추가 |
| `iosTests/Shared/WorkoutMetricsTests.swift` | formatSeconds 테스트 추가 |
| `iOSApp/Features/Summary/SummaryViewModel.swift` | SummaryStats 필드 변경, stats 집계 로직, calculateStreak 제거 |
| `iosTests/Summary/SummaryViewModelTests.swift` | 신규 생성 — SummaryViewModel 테스트 |
| `iOSApp/Features/Summary/SummaryView.swift` | matchStatsSection(3열), fitnessSection 추가 |
| `iOSApp/Components/MatchDetailSheet.swift` | WorkoutStatCell private struct, Workout 섹션, Info 정리 |
| `iOSApp/Features/History/Components/CalendarHistoryView.swift` | 탭 동작 max(by:) 수정 |

---

## Task 1: WorkoutMetrics에 formatSeconds 추가

**Files:**
- Modify: `Shared/Models/WorkoutMetrics.swift`
- Modify: `iosTests/Shared/WorkoutMetricsTests.swift`

- [ ] **Step 1: 실패하는 테스트 작성**

`iosTests/Shared/WorkoutMetricsTests.swift` 파일 끝에 두 테스트 추가:

```swift
@Test func formatSecondsUnderOneHour() {
    #expect(WorkoutMetrics.formatSeconds(150) == "02:30")
}

@Test func formatSecondsOverOneHour() {
    #expect(WorkoutMetrics.formatSeconds(3661) == "1:01:01")
}
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(formatSeconds|error:|Build failed)"
```

Expected: `error: value of type 'WorkoutMetrics' has no member 'formatSeconds'` 또는 빌드 실패.

- [ ] **Step 3: formatSeconds static 메서드 구현**

`Shared/Models/WorkoutMetrics.swift` 의 `formattedElapsed` 아래에 추가:

```swift
static func formatSeconds(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let secs = seconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%02d:%02d", minutes, secs)
}
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(Test.*formatSeconds|PASSED|FAILED|Build failed)"
```

Expected: 두 테스트 모두 PASSED.

---

## Task 2: SummaryViewModel 업데이트

**Files:**
- Modify: `iOSApp/Features/Summary/SummaryViewModel.swift`
- Create: `iosTests/Summary/SummaryViewModelTests.swift`

- [ ] **Step 1: 테스트 파일 생성**

`iosTests/Summary/SummaryViewModelTests.swift` 신규 생성:

```swift
@testable import TennisCounter
import Testing

@MainActor
struct SummaryViewModelTests {
    @Test func statsWithNoWorkoutData_returnNilFitnessStats() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .all

        let match = Match()
        match.myTotalSets = 2
        match.yourTotalSets = 1
        match.startedAt = Date()

        let stats = vm.stats(from: [match])

        #expect(stats.totalCalories == nil)
        #expect(stats.totalDuration == nil)
        #expect(stats.avgHeartRate == nil)
    }

    @Test func statsWithWorkoutData_aggregatesCorrectly() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .all

        let match1 = Match()
        match1.myTotalSets = 2
        match1.yourTotalSets = 0
        match1.startedAt = Date()
        match1.caloriesBurned = 300
        match1.averageHeartRate = 140
        match1.durationSeconds = 3600

        let match2 = Match()
        match2.myTotalSets = 0
        match2.yourTotalSets = 2
        match2.startedAt = Date()
        match2.caloriesBurned = 200
        match2.averageHeartRate = 160
        match2.durationSeconds = 1800

        let stats = vm.stats(from: [match1, match2])

        #expect(stats.totalCalories == 500)
        #expect(stats.totalDuration == 5400)
        #expect(stats.avgHeartRate == 150)
    }

    @Test func statsWithMixedWorkoutData_onlyAggregatesAvailableData() {
        let vm = SummaryViewModel()
        vm.selectedPeriod = .all

        let matchWithData = Match()
        matchWithData.myTotalSets = 2
        matchWithData.yourTotalSets = 0
        matchWithData.startedAt = Date()
        matchWithData.caloriesBurned = 400
        matchWithData.averageHeartRate = 150
        matchWithData.durationSeconds = 2700

        let matchWithoutData = Match()
        matchWithoutData.myTotalSets = 1
        matchWithoutData.yourTotalSets = 2
        matchWithoutData.startedAt = Date()

        let stats = vm.stats(from: [matchWithData, matchWithoutData])

        #expect(stats.totalCalories == 400)
        #expect(stats.totalDuration == 2700)
        #expect(stats.avgHeartRate == 150)
        #expect(stats.totalMatches == 2)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인 (SummaryStats 타입 불일치)**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(SummaryViewModel|error:|Build failed)" | head -10
```

Expected: `totalCalories`, `totalDuration`, `avgHeartRate` 멤버 없음 관련 컴파일 에러.

- [ ] **Step 3: SummaryViewModel.swift 전체 교체**

`iOSApp/Features/Summary/SummaryViewModel.swift` 를 아래로 교체:

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
    let totalCalories: Double?
    let totalDuration: Int?
    let avgHeartRate: Double?

    var formattedCalories: String {
        totalCalories.map { String(format: "%.0f", $0) } ?? "–"
    }

    var formattedDuration: String {
        totalDuration.map { WorkoutMetrics.formatSeconds($0) } ?? "–"
    }

    var formattedHeartRate: String {
        avgHeartRate.map { String(format: "%.0f", $0) } ?? "–"
    }
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

        let calories = filtered.compactMap(\.caloriesBurned)
        let totalCalories: Double? = calories.isEmpty ? nil : calories.reduce(0, +)

        let durations: [Int] = filtered.compactMap { match in
            if let d = match.durationSeconds { return d }
            if let end = match.endedAt { return Int(end.timeIntervalSince(match.startedAt)) }
            return nil
        }
        let totalDuration: Int? = durations.isEmpty ? nil : durations.reduce(0, +)

        let heartRates = filtered.compactMap(\.averageHeartRate)
        let avgHeartRate: Double? = heartRates.isEmpty ? nil : heartRates.reduce(0, +) / Double(heartRates.count)

        return SummaryStats(
            totalMatches: total,
            wins: wins,
            winRate: winRate,
            totalCalories: totalCalories,
            totalDuration: totalDuration,
            avgHeartRate: avgHeartRate
        )
    }

    func recentMatches(from matches: [Match]) -> [Match] {
        Array(matches.prefix(2))
    }

    func filteredMatches(from matches: [Match]) -> [Match] {
        guard let start = selectedPeriod.startDate() else { return matches }
        return matches.filter { $0.startedAt >= start }
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(SummaryViewModelTests|PASSED|FAILED|Build failed)"
```

Expected: 세 테스트 모두 PASSED.

---

## Task 3: SummaryView UI 업데이트

**Files:**
- Modify: `iOSApp/Features/Summary/SummaryView.swift`

View는 테스트하지 않음 (CLAUDE.md 규칙).

- [ ] **Step 1: SummaryView.swift 전체 교체**

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
                    matchStatsSection
                    fitnessSection
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

    private var matchStatsSection: some View {
        let stats = viewModel.stats(from: matches)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(title: String(localized: "summary_total_matches"), value: "\(stats.totalMatches)", color: .blue)
            StatCard(
                title: String(localized: "summary_win_rate"),
                value: String(format: "%.0f%%", stats.winRate * 100),
                color: stats.winRate >= 0.5 ? .green : .orange
            )
            StatCard(title: "Wins", value: "\(stats.wins)", color: .green)
        }
    }

    private var fitnessSection: some View {
        let stats = viewModel.stats(from: matches)
        return VStack(alignment: .leading, spacing: 12) {
            Text("피트니스")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatCard(title: "총 kcal", value: stats.formattedCalories, color: .orange)
                StatCard(title: "운동시간", value: stats.formattedDuration, color: .blue)
                StatCard(title: "평균 bpm", value: stats.formattedHeartRate, color: .red)
            }
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

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "(error:|Build succeeded|Build failed)"
```

Expected: `Build succeeded`

---

## Task 4: MatchDetailSheet 업데이트

**Files:**
- Modify: `iOSApp/Components/MatchDetailSheet.swift`

View는 테스트하지 않음.

- [ ] **Step 1: MatchDetailSheet.swift 전체 교체**

```swift
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

                Section(header: Text("Workout")) {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 12
                    ) {
                        WorkoutStatCell(
                            icon: "flame.fill",
                            iconColor: .orange,
                            value: match.caloriesBurned.map { String(format: "%.0f", $0) } ?? "–",
                            unit: "kcal"
                        )
                        WorkoutStatCell(
                            icon: "timer",
                            iconColor: .blue,
                            value: matchDurationString,
                            unit: ""
                        )
                        WorkoutStatCell(
                            icon: "heart.fill",
                            iconColor: .red,
                            value: match.averageHeartRate.map { String(format: "%.0f", $0) } ?? "–",
                            unit: "BPM"
                        )
                    }
                    .listRowInsets(EdgeInsets())
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

private struct WorkoutStatCell: View {
    let icon: String
    let iconColor: Color
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
            Text(value)
                .font(.system(size: 18, weight: .semibold))
            if value != "–", !unit.isEmpty {
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "(error:|Build succeeded|Build failed)"
```

Expected: `Build succeeded`

---

## Task 5: CalendarHistoryView 탭 동작 수정

**Files:**
- Modify: `iOSApp/Features/History/Components/CalendarHistoryView.swift`

- [ ] **Step 1: daysGrid의 탭 동작 수정**

`CalendarHistoryView.swift` 의 `daysGrid` 내부에서:

```swift
// 변경 전
selectedMatch = dayMatches.first

// 변경 후
selectedMatch = dayMatches.max(by: { $0.startedAt < $1.startedAt })
```

`daysGrid` computed property 전체:

```swift
private var daysGrid: some View {
    let days = daysInMonth()
    return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
        ForEach(Array(days.enumerated()), id: \.offset) { _, date in
            if let date {
                let dayMatches = matchesForDate(date)
                DayCell(date: date, matches: dayMatches) {
                    selectedMatch = dayMatches.max(by: { $0.startedAt < $1.startedAt })
                }
            } else {
                Color.clear.frame(height: 36)
            }
        }
    }
    .padding(.horizontal, 4)
}
```

- [ ] **Step 2: 전체 빌드 및 테스트 최종 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "(PASSED|FAILED|Build succeeded|Build failed|error:)"
```

Expected: `Build succeeded`, 모든 테스트 PASSED.
