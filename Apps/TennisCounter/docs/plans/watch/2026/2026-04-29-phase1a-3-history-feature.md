# Phase 1-A ③ History Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 저장된 경기 기록을 달력/리스트 토글로 볼 수 있는 History 탭 구현. 각 경기 탭 시 세트별 상세 결과 표시.

**Architecture:** `HistoryViewModel`이 SwiftData `@Query`로 Match 목록 조회. `HistoryView`는 캘린더 뷰(날짜별 점 표시) 또는 리스트 뷰(최신순)를 토글. `MatchHistoryDetailView`는 Sheet로 세트 결과 표시. iOSApp.swift History 탭 placeholder를 `HistoryView()`로 교체.

**Tech Stack:** SwiftUI, SwiftData @Query

**선행 조건:** `2026-04-29-phase1a-1-data-foundation.md` 완료 (Match/SetRecord 모델 존재)

---

## File Structure

| 파일 | 액션 | 역할 |
|------|------|------|
| `iOSApp/Features/History/HistoryView.swift` | Create | 기록 탭 루트 뷰 |
| `iOSApp/Features/History/HistoryViewModel.swift` | Create | 조회/필터 로직 |
| `iOSApp/Features/History/Components/MatchRowView.swift` | Create | 리스트 행 컴포넌트 |
| `iOSApp/Features/History/Components/MatchDetailSheet.swift` | Create | 경기 상세 Sheet |
| `iOSApp/Features/History/Components/CalendarHistoryView.swift` | Create | 달력 뷰 |
| `iOSApp/iOSApp.swift` | Modify | History 탭 placeholder → HistoryView() |

---

### Task 1: HistoryViewModel

**Files:**
- Create: `iOSApp/Features/History/HistoryViewModel.swift`

- [ ] **Step 1: 디렉터리 생성**

```bash
mkdir -p iOSApp/Features/History/Components
```

- [ ] **Step 2: HistoryViewModel.swift 생성**

```swift
import Foundation
import SwiftData

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

### Task 2: MatchRowView (리스트 행)

**Files:**
- Create: `iOSApp/Features/History/Components/MatchRowView.swift`

- [ ] **Step 1: MatchRowView.swift 생성**

```swift
import SwiftUI

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

                    Text(formatName(match.matchFormat))
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

- [ ] **Step 2: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

---

### Task 3: MatchDetailSheet (경기 상세)

**Files:**
- Create: `iOSApp/Features/History/Components/MatchDetailSheet.swift`

- [ ] **Step 1: MatchDetailSheet.swift 생성**

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
                        Text(match.matchFormat == "one_set"
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

- [ ] **Step 2: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

---

### Task 4: CalendarHistoryView (달력 뷰)

**Files:**
- Create: `iOSApp/Features/History/Components/CalendarHistoryView.swift`

- [ ] **Step 1: CalendarHistoryView.swift 생성**

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

### Task 5: HistoryView 루트

**Files:**
- Create: `iOSApp/Features/History/HistoryView.swift`

- [ ] **Step 1: HistoryView.swift 생성**

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
git add iOSApp/Features/History/
git commit -m "feat: add History tab with list and calendar view"
```

---

### Task 6: iOSApp.swift History 탭 연결

**Files:**
- Modify: `iOSApp/iOSApp.swift`

- [ ] **Step 1: iOSApp.swift에서 History 탭 placeholder 교체**

`Text("History")` 부분을:

```swift
HistoryView()
    .tabItem {
        Label(String(localized: "tab_history"), systemImage: "clock.fill")
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

1. 앱 실행 → History 탭 진입 → "No matches recorded" 빈 상태 확인
2. Match 탭에서 경기 완료 후 History 탭 → 방금 경기 목록 표시 확인
3. 경기 탭 → 상세 Sheet 열림 확인
4. 상단 아이콘 탭 → 달력 뷰 전환 확인

- [ ] **Step 4: 커밋**

```bash
git add iOSApp/iOSApp.swift
git commit -m "feat: connect HistoryView to History tab"
```

---

## 완료 기준

- [x] History 탭 진입 시 경기 목록(최신순) 표시
- [x] 경기 없으면 빈 상태 메시지 표시
- [x] 경기 탭 → 세트별 결과 Sheet 표시
- [x] 달력/리스트 토글 동작
- [x] 달력에서 경기 있는 날 dot 표시 (승=초록, 패=주황)
- [x] iOS 빌드 성공
