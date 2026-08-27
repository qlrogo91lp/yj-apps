# Phase 1-A ④ Summary Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 오늘/이번 주/이번 달/전체 기간별 통계 카드(경기 수, 승률, 연속 플레이 streak), 최근 경기 2개 카드를 표시하는 Summary 탭 구현

**Architecture:** `SummaryViewModel`이 SwiftData `@Query` 결과를 받아 기간 필터링 + 집계. 기간 토글은 `Picker`. 최근 경기 카드 탭 시 History 탭의 `MatchDetailSheet`를 재사용. iOSApp.swift Summary 탭 placeholder를 `SummaryView()`로 교체.

**Tech Stack:** SwiftUI, SwiftData @Query, Combine

**선행 조건:** `2026-04-29-phase1a-1-data-foundation.md` 완료 (Match 모델 존재)

---

## File Structure

| 파일 | 액션 | 역할 |
|------|------|------|
| `iOSApp/Features/Summary/SummaryView.swift` | Create | 요약 탭 루트 뷰 |
| `iOSApp/Features/Summary/SummaryViewModel.swift` | Create | 기간 필터 + 통계 집계 |
| `iOSApp/iOSApp.swift` | Modify | Summary 탭 placeholder → SummaryView() |

---

### Task 1: SummaryPeriod enum

**Files:**
- Create: `iOSApp/Features/Summary/SummaryPeriod.swift`

- [ ] **Step 1: 디렉터리 생성**

```bash
mkdir -p iOSApp/Features/Summary
```

- [ ] **Step 2: SummaryPeriod.swift 생성**

```swift
import Foundation

enum SummaryPeriod: String, CaseIterable {
    case today
    case week
    case month
    case all

    var localizedTitle: String {
        switch self {
        case .today: return String(localized: "summary_period_today")
        case .week: return String(localized: "summary_period_week")
        case .month: return String(localized: "summary_period_month")
        case .all: return String(localized: "summary_period_all")
        }
    }

    func startDate(from now: Date = Date()) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .today:
            return calendar.startOfDay(for: now)
        case .week:
            return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))
        case .month:
            let components = calendar.dateComponents([.year, .month], from: now)
            return calendar.date(from: components)
        case .all:
            return nil
        }
    }
}
```

- [ ] **Step 3: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

---

### Task 2: SummaryViewModel

**Files:**
- Create: `iOSApp/Features/Summary/SummaryViewModel.swift`

- [ ] **Step 1: SummaryViewModel.swift 생성**

```swift
import Foundation

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
        let wins = filtered.filter { $0.myTotalSets > $0.yourTotalSets }.count
        let total = filtered.count
        let winRate = total > 0 ? Double(wins) / Double(total) : 0.0

        return SummaryStats(
            totalMatches: total,
            wins: wins,
            winRate: winRate,
            streak: calculateStreak(from: matches)
        )
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

- [ ] **Step 2: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

---

### Task 3: SummaryView

**Files:**
- Create: `iOSApp/Features/Summary/SummaryView.swift`

- [ ] **Step 1: SummaryView.swift 생성**

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

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $viewModel.selectedPeriod) {
            ForEach(SummaryPeriod.allCases, id: \.rawValue) { period in
                Text(period.localizedTitle).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        let stats = viewModel.stats(from: matches)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            StatCard(
                title: String(localized: "summary_total_matches"),
                value: "\(stats.totalMatches)",
                systemImage: "sportscourt.fill",
                color: .blue
            )

            StatCard(
                title: String(localized: "summary_win_rate"),
                value: String(format: "%.0f%%", stats.winRate * 100),
                systemImage: "trophy.fill",
                color: stats.winRate >= 0.5 ? .green : .orange
            )

            StatCard(
                title: String(localized: "summary_streak"),
                value: "\(stats.streak)",
                systemImage: "flame.fill",
                color: .red
            )

            StatCard(
                title: "Wins",
                value: "\(stats.wins)",
                systemImage: "checkmark.circle.fill",
                color: .green
            )
        }
    }

    // MARK: - Recent Matches

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

// MARK: - StatCard

private struct StatCard: View {
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

// MARK: - RecentMatchCard

private struct RecentMatchCard: View {
    let match: Match

    private var didWin: Bool { match.myTotalSets > match.yourTotalSets }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(didWin ? String(localized: "match_over_win") : String(localized: "match_over_lose"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(didWin ? .green : .orange)

                    Text(match.matchFormat == "one_set"
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

struct SummaryView_Previews: PreviewProvider {
    static var previews: some View {
        SummaryView()
    }
}
```

- [ ] **Step 2: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋**

```bash
git add iOSApp/Features/Summary/
git commit -m "feat: add Summary tab with period stats and recent matches"
```

---

### Task 4: iOSApp.swift Summary 탭 연결

**Files:**
- Modify: `iOSApp/iOSApp.swift`

- [ ] **Step 1: iOSApp.swift에서 Summary 탭 placeholder 교체**

`Text("Summary")` 부분을:

```swift
SummaryView()
    .tabItem {
        Label(String(localized: "tab_summary"), systemImage: "chart.bar.fill")
    }
```

으로 교체.

- [ ] **Step 2: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 시뮬레이터 스모크 테스트**

1. 앱 실행 → Summary 탭 → 경기 0개 상태 통계 표시 확인 (0%, 0게임)
2. Match 탭에서 경기 완료 후 Summary 탭 → 통계 업데이트 확인
3. 기간 Picker 탭(이번 주 / 오늘 / 전체) → 수치 변경 확인
4. 최근 경기 카드 탭 → MatchDetailSheet 열림 확인

- [ ] **Step 4: 커밋**

```bash
git add iOSApp/iOSApp.swift
git commit -m "feat: connect SummaryView to Summary tab"
```

---

## 완료 기준

- [x] Summary 탭 진입 시 기간 Picker + 통계 카드 4개 표시
- [x] 기간 변경 시 경기 수/승률 수치 실시간 반영
- [x] 최근 경기 2개 카드 표시 (탭 시 상세 Sheet)
- [x] streak 계산: 연속 플레이 일수
- [x] iOS 빌드 성공
