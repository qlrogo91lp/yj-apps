# History 무한 스크롤 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `HistoryView`의 `@Query` 전체 로드를 제거하고 ViewModel이 ModelContext를 직접 소유해 리스트는 20개씩 페이지네이션, 캘린더는 현재 월만 fetch하는 구조로 전환한다.

**Architecture:** `HistoryViewModel`이 `ModelContext`를 받아 `FetchDescriptor`로 직접 쿼리를 제어한다. 리스트는 스크롤 끝에서 5번째 아이템 `.onAppear` 트리거로 다음 페이지를 append하고, 캘린더는 월 이동 시 해당 월 범위만 재조회한다.

**Tech Stack:** SwiftData (`ModelContext`, `FetchDescriptor`, `#Predicate`), SwiftUI (`LazyVStack`, `ProgressView`), Swift Testing

---

## 파일 구조

| 역할 | 파일 |
|------|------|
| Date 월 범위 계산 | `iOSApp/Extensions/Date+Month.swift` (신규) |
| 페이지네이션 + 캘린더 로직 | `iOSApp/Features/History/HistoryViewModel.swift` (수정) |
| 스크롤 트리거 + 로딩 인디케이터 | `iOSApp/Features/History/Components/MatchList.swift` (수정) |
| 월 상태 외부 제어로 전환 | `iOSApp/Features/History/Calendar/CalendarView.swift` (수정) |
| @Query 제거 + viewModel 연결 | `iOSApp/Features/History/HistoryView.swift` (수정) |
| ViewModel 테스트 | `iosTests/History/HistoryViewModelTests.swift` (신규) |

---

## Task 1: Date Extension

**Files:**
- Create: `iOSApp/Extensions/Date+Month.swift`

- [ ] **Step 1: 파일 생성**

```swift
// iOSApp/Extensions/Date+Month.swift
import Foundation

extension Date {
    var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components) ?? self
    }

    var endOfMonth: Date {
        var components = DateComponents()
        components.month = 1
        return Calendar.current.date(byAdding: components, to: startOfMonth) ?? self
    }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋**

```bash
git add iOSApp/Extensions/Date+Month.swift
git commit -m "feat: add Date startOfMonth/endOfMonth extensions"
```

---

## Task 2: HistoryViewModel 스켈레톤

**Files:**
- Modify: `iOSApp/Features/History/HistoryViewModel.swift`

현재 파일 전체를 교체한다. 메서드는 빈 스텁으로 두어 컴파일만 통과시킨다. 테스트에서 참조할 `@Published` 프로퍼티를 먼저 선언한다.

- [ ] **Step 1: HistoryViewModel 스켈레톤으로 교체**

```swift
// iOSApp/Features/History/HistoryViewModel.swift
import Foundation
import SwiftData

enum HistoryViewMode {
    case list
    case calendar
}

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var viewMode: HistoryViewMode = .list
    @Published var listMatches: [Match] = []
    @Published var calendarMatches: [Match] = []
    @Published var isLoadingMore: Bool = false
    @Published var hasMore: Bool = true
    @Published var currentMonth: Date = Date()

    private var modelContext: ModelContext?
    private var currentPage: Int = 0
    private let pageSize: Int = 20

    func configure(modelContext: ModelContext) {}
    func loadInitial() {}
    func loadNextPage() {}
    func changeMonth(by value: Int) {}

    func toggleViewMode() {
        viewMode = viewMode == .list ? .calendar : .list
    }

    private func loadCalendarMatches() {}
}
```

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

---

## Task 3: 페이지네이션 테스트 작성 → loadInitial + loadNextPage 구현

**Files:**
- Create: `iosTests/History/HistoryViewModelTests.swift`
- Modify: `iOSApp/Features/History/HistoryViewModel.swift`

- [ ] **Step 1: 실패하는 테스트 4개 작성**

```swift
// iosTests/History/HistoryViewModelTests.swift
@testable import TennisCounter
import Foundation
import Testing
import SwiftData

@MainActor
struct HistoryViewModelTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Match.self, SetRecord.self, configurations: config)
        return ModelContext(container)
    }

    private func insertMatches(count: Int, in context: ModelContext) throws {
        for i in 0..<count {
            let match = Match()
            match.startedAt = Date().addingTimeInterval(TimeInterval(-i * 3600))
            context.insert(match)
        }
        try context.save()
    }

    @Test func loadInitial_setsFirstPage() throws {
        let context = try makeContext()
        try insertMatches(count: 25, in: context)

        let vm = HistoryViewModel()
        vm.configure(modelContext: context)
        vm.loadInitial()

        #expect(vm.listMatches.count == 20)
        #expect(vm.hasMore == true)
    }

    @Test func loadNextPage_appendsMatches() throws {
        let context = try makeContext()
        try insertMatches(count: 25, in: context)

        let vm = HistoryViewModel()
        vm.configure(modelContext: context)
        vm.loadInitial()
        vm.loadNextPage()

        #expect(vm.listMatches.count == 25)
        #expect(vm.hasMore == false)
    }

    @Test func loadNextPage_setsHasMoreFalse_whenFewerThanPageSize() throws {
        let context = try makeContext()
        try insertMatches(count: 10, in: context)

        let vm = HistoryViewModel()
        vm.configure(modelContext: context)
        vm.loadInitial()

        #expect(vm.listMatches.count == 10)
        #expect(vm.hasMore == false)
    }

    @Test func loadNextPage_doesNothing_whenIsLoadingMore() throws {
        let context = try makeContext()
        try insertMatches(count: 25, in: context)

        let vm = HistoryViewModel()
        vm.configure(modelContext: context)
        vm.loadInitial()

        vm.isLoadingMore = true
        vm.loadNextPage()

        #expect(vm.listMatches.count == 20)
    }
}
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing "TennisCounterTests/HistoryViewModelTests" 2>&1 | grep -E "FAIL|PASS|error:"
```

Expected: 4개 테스트 모두 FAIL (listMatches.count == 0)

- [ ] **Step 3: configure + loadInitial + loadNextPage 구현**

`HistoryViewModel.swift`의 스텁 메서드를 교체한다:

```swift
func configure(modelContext: ModelContext) {
    guard self.modelContext == nil else { return }
    self.modelContext = modelContext
}

func loadInitial() {
    currentPage = 0
    listMatches = []
    hasMore = true
    loadNextPage()
    loadCalendarMatches()
}

func loadNextPage() {
    guard !isLoadingMore, hasMore, let context = modelContext else { return }
    isLoadingMore = true

    var descriptor = FetchDescriptor<Match>(
        sortBy: [SortDescriptor(\Match.startedAt, order: .reverse)]
    )
    descriptor.fetchLimit = pageSize
    descriptor.fetchOffset = currentPage * pageSize

    let fetched = (try? context.fetch(descriptor)) ?? []
    listMatches.append(contentsOf: fetched)
    hasMore = fetched.count == pageSize
    currentPage += 1
    isLoadingMore = false
}
```

- [ ] **Step 4: 테스트 실행 — 4개 모두 통과 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing "TennisCounterTests/HistoryViewModelTests" 2>&1 | grep -E "FAIL|PASS|error:"
```

Expected: `Test Suite ... passed` (4개 PASS)

- [ ] **Step 5: 커밋**

```bash
git add iosTests/History/HistoryViewModelTests.swift \
        iOSApp/Features/History/HistoryViewModel.swift
git commit -m "feat: add HistoryViewModel pagination with tests"
```

---

## Task 4: 캘린더 테스트 작성 → changeMonth + loadCalendarMatches 구현

**Files:**
- Modify: `iosTests/History/HistoryViewModelTests.swift`
- Modify: `iOSApp/Features/History/HistoryViewModel.swift`

- [ ] **Step 1: 실패하는 테스트 1개 추가**

`HistoryViewModelTests` struct 안에 다음 테스트를 추가한다:

```swift
@Test func changeMonth_updatesCalendarMatches() throws {
    let context = try makeContext()
    let now = Date()
    let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: now)!

    let currentMonthMatch = Match()
    currentMonthMatch.startedAt = now
    context.insert(currentMonthMatch)

    let nextMonthMatch = Match()
    nextMonthMatch.startedAt = nextMonth
    context.insert(nextMonthMatch)

    try context.save()

    let vm = HistoryViewModel()
    vm.configure(modelContext: context)
    vm.loadInitial()

    #expect(vm.calendarMatches.count == 1)
    #expect(Calendar.current.isDate(vm.calendarMatches[0].startedAt, equalTo: now, toGranularity: .month))

    vm.changeMonth(by: 1)

    #expect(vm.calendarMatches.count == 1)
    #expect(Calendar.current.isDate(vm.calendarMatches[0].startedAt, equalTo: nextMonth, toGranularity: .month))
}
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing "TennisCounterTests/HistoryViewModelTests" 2>&1 | grep -E "FAIL|PASS|error:"
```

Expected: `changeMonth_updatesCalendarMatches` FAIL (calendarMatches.count == 0)

- [ ] **Step 3: changeMonth + loadCalendarMatches 구현**

`HistoryViewModel.swift`의 스텁 메서드를 교체한다:

```swift
func changeMonth(by value: Int) {
    if let newMonth = Calendar.current.date(byAdding: .month, value: value, to: currentMonth) {
        currentMonth = newMonth
        loadCalendarMatches()
    }
}

private func loadCalendarMatches() {
    guard let context = modelContext else { return }
    let start = currentMonth.startOfMonth
    let end = currentMonth.endOfMonth

    let predicate = #Predicate<Match> { $0.startedAt >= start && $0.startedAt < end }
    var descriptor = FetchDescriptor<Match>(
        predicate: predicate,
        sortBy: [SortDescriptor(\Match.startedAt, order: .reverse)]
    )
    calendarMatches = (try? context.fetch(descriptor)) ?? []
}
```

- [ ] **Step 4: 전체 5개 테스트 모두 통과 확인**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing "TennisCounterTests/HistoryViewModelTests" 2>&1 | grep -E "FAIL|PASS|error:"
```

Expected: 5개 모두 PASS

- [ ] **Step 5: 커밋**

```bash
git add iosTests/History/HistoryViewModelTests.swift \
        iOSApp/Features/History/HistoryViewModel.swift
git commit -m "feat: add HistoryViewModel calendar month fetch with test"
```

---

## Task 5: MatchList 페이지네이션 UI

**Files:**
- Modify: `iOSApp/Features/History/Components/MatchList.swift`

현재 시그니처: `MatchList(matches: [Match], onSelect: (Match) -> Void)`
변경 후 시그니처: `MatchList(matches: [Match], isLoadingMore: Bool, onLoadMore: () -> Void, onSelect: (Match) -> Void)`

- [ ] **Step 1: MatchList.swift 전체 교체**

```swift
// iOSApp/Features/History/Components/MatchList.swift
import SwiftUI

struct MatchList: View {
    let matches: [Match]
    let isLoadingMore: Bool
    let onLoadMore: () -> Void
    let onSelect: (Match) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(Array(matches.enumerated()), id: \.element.id) { index, match in
                    MatchCard(match: match)
                        .onTapGesture { onSelect(match) }
                        .onAppear {
                            if index == matches.count - 5 {
                                onLoadMore()
                            }
                        }
                }

                if isLoadingMore {
                    ProgressView()
                        .padding(.vertical, 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}
```

- [ ] **Step 2: 빌드 확인 (HistoryView가 아직 구 시그니처를 쓰므로 에러 예상)**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep "error:"
```

Expected: `HistoryView.swift`에서 `MatchList` 시그니처 불일치 에러 — 다음 Task에서 수정

---

## Task 6: CalendarView 외부 제어로 전환

**Files:**
- Modify: `iOSApp/Features/History/Calendar/CalendarView.swift`

내부 `@State private var displayedMonth` 제거, 외부 props로 교체한다.

- [ ] **Step 1: CalendarView.swift 전체 교체**

```swift
// iOSApp/Features/History/Calendar/CalendarView.swift
import SwiftUI

struct CalendarView: View {
    let matches: [Match]
    let currentMonth: Date
    let onPrevious: () -> Void
    let onNext: () -> Void
    @Binding var selectedMatch: Match?

    var body: some View {
        VStack(spacing: 0) {
            MonthHeader(
                displayedMonth: currentMonth,
                onPrevious: onPrevious,
                onNext: onNext
            )
            WeekdayLabels()
            CalendarGrid(
                matches: matches,
                displayedMonth: currentMonth,
                selectedMatch: $selectedMatch
            )
        }
    }
}
```

- [ ] **Step 2: 빌드 에러 확인 (HistoryView의 CalendarView 호출도 구 시그니처)**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep "error:"
```

Expected: `HistoryView.swift`에서 `CalendarView` 시그니처 불일치 에러 — 다음 Task에서 수정

---

## Task 7: HistoryView 전체 연결

**Files:**
- Modify: `iOSApp/Features/History/HistoryView.swift`

`@Query` 제거, viewModel 상태를 MatchList·CalendarView에 연결한다.

- [ ] **Step 1: HistoryView.swift 전체 교체**

```swift
// iOSApp/Features/History/HistoryView.swift
import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = HistoryViewModel()
    @State private var selectedMatch: Match?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.viewMode == .list {
                    if viewModel.listMatches.isEmpty && !viewModel.isLoadingMore {
                        HistoryEmptyState()
                    } else {
                        MatchList(
                            matches: viewModel.listMatches,
                            isLoadingMore: viewModel.isLoadingMore,
                            onLoadMore: { viewModel.loadNextPage() },
                            onSelect: { selectedMatch = $0 }
                        )
                    }
                } else {
                    ScrollView {
                        CalendarView(
                            matches: viewModel.calendarMatches,
                            currentMonth: viewModel.currentMonth,
                            onPrevious: { viewModel.changeMonth(by: -1) },
                            onNext: { viewModel.changeMonth(by: 1) },
                            selectedMatch: $selectedMatch
                        )
                        .padding()
                    }
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
            .onAppear {
                viewModel.configure(modelContext: modelContext)
                viewModel.loadInitial()
            }
        }
    }
}
```

- [ ] **Step 2: 전체 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 전체 테스트 실행**

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "FAIL|PASS|error:|Suite"
```

Expected: 전체 테스트 PASS

- [ ] **Step 4: 최종 커밋**

```bash
git add iOSApp/Features/History/Components/MatchList.swift \
        iOSApp/Features/History/Calendar/CalendarView.swift \
        iOSApp/Features/History/HistoryView.swift
git commit -m "feat: wire HistoryView to paginated ViewModel with CalendarView external control"
```
