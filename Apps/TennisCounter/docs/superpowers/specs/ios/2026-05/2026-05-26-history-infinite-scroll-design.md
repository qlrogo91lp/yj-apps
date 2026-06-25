# History 리스트 무한 스크롤 설계

**날짜**: 2026-05-26
**대상**: iOS History 피처 (리스트 뷰 페이지네이션 + 캘린더 뷰 월별 fetch)

---

## 요약

현재 `HistoryView`는 `@Query`로 전체 매치를 한 번에 로드한다. 매치 수가 늘어날수록 메모리 낭비가 커지므로, `HistoryViewModel`이 `ModelContext`를 직접 소유해 쿼리를 제어하는 구조로 전환한다.

- **리스트 뷰**: 20개씩 페이지네이션 (스크롤 끝 자동 감지)
- **캘린더 뷰**: 현재 월만 fetch (월 이동 시 재조회)

---

## 아키텍처 / 데이터 흐름

### 변경 전
```
HistoryView
  @Query(전체) → matches: [Match]
    → MatchList(matches: 전체)
    → CalendarView(matches: 전체, displayedMonth: @State 내부)
```

### 변경 후
```
HistoryView
  @Environment(\.modelContext)
  @StateObject HistoryViewModel
    → MatchList(matches: listMatches, isLoadingMore:, onLoadMore:)
    → CalendarView(matches: calendarMatches, currentMonth:, onPrevious:, onNext:)
```

`CalendarView`의 `displayedMonth` 상태를 ViewModel로 끌어올려 월 이동 시 ViewModel이 캘린더 데이터를 재조회한다.

---

## HistoryViewModel

### 상태

```swift
@Published var viewMode: HistoryViewMode = .list
@Published var listMatches: [Match] = []
@Published var calendarMatches: [Match] = []
@Published var isLoadingMore: Bool = false
@Published var hasMore: Bool = true
@Published var currentMonth: Date = Date()

private var modelContext: ModelContext?
private var currentPage: Int = 0
private let pageSize: Int = 20
```

### 메서드

| 메서드 | 역할 |
|--------|------|
| `configure(modelContext:)` | View에서 ModelContext 주입 (최초 1회, `guard self.modelContext == nil`으로 중복 방어) |
| `loadInitial()` | 페이지 리셋 후 첫 20개 + 현재 월 fetch |
| `loadNextPage()` | 다음 20개 append (`isLoadingMore`, `hasMore` 체크로 중복 호출 방어) |
| `changeMonth(by:)` | 월 이동 + `calendarMatches` 재조회 |
| `toggleViewMode()` | 기존 그대로 |

### 페이지네이션 로직

```swift
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

### 캘린더 월별 fetch 로직

```swift
private func loadCalendarMatches() {
    guard let context = modelContext else { return }
    let start = currentMonth.startOfMonth  // Date extension 필요
    let end = currentMonth.endOfMonth      // Date extension 필요

    let predicate = #Predicate<Match> { $0.startedAt >= start && $0.startedAt < end }
    var descriptor = FetchDescriptor<Match>(
        predicate: predicate,
        sortBy: [SortDescriptor(\Match.startedAt, order: .reverse)]
    )
    calendarMatches = (try? context.fetch(descriptor)) ?? []
}
```

`Date.startOfMonth` / `Date.endOfMonth`는 구현 시 `Shared/` 또는 `iOSApp/` 적절한 위치에 extension으로 추가해야 한다.

### 새 매치 반영

`HistoryView.onAppear`에서 `viewModel.loadInitial()` 호출. History 탭 재진입 시 리셋되므로 별도 notification 불필요.

---

## HistoryView 변경

```swift
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
            .toolbar { /* 기존 viewMode 토글 버튼 그대로 */ }
            .sheet(item: $selectedMatch) { MatchDetailSheet(match: $0) }
            .onAppear {
                viewModel.configure(modelContext: modelContext)
                viewModel.loadInitial()
            }
        }
    }
}
```

`.onAppear`만 사용 — configure는 `guard self.modelContext == nil`으로 중복 주입 방어, loadInitial은 탭 재진입마다 리스트를 최신 상태로 리셋.

---

## MatchList 변경

```swift
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

- **트리거**: 끝에서 5번째 아이템 `.onAppear` 시 `onLoadMore()` 호출
- **중복 방어**: ViewModel의 `isLoadingMore` / `hasMore`로 처리
- **로딩 인디케이터**: `isLoadingMore`일 때 리스트 하단 `ProgressView` 표시
- 총 매치가 20개 미만이면 `hasMore = false`로 추가 호출 없음

---

## CalendarView 변경

내부 `@State private var displayedMonth` 제거, 외부 제어로 전환.

```swift
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

`changeMonth(by:)` 로직은 ViewModel로 이동. CalendarView는 표현만 담당.

---

## 테스트

| 테스트 | 대상 |
|--------|------|
| `loadInitial_setsFirstPage` | 초기 로드 시 listMatches에 최대 20개 |
| `loadNextPage_appendsMatches` | 페이지 추가 시 기존 데이터 유지 + append |
| `loadNextPage_setsHasMoreFalse_whenFewerThanPageSize` | 20개 미만 반환 시 hasMore = false |
| `loadNextPage_doesNothing_whenIsLoadingMore` | 중복 호출 방어 |
| `changeMonth_updatesCalendarMatches` | 월 이동 시 해당 월 데이터만 로드 |

테스트 파일 위치: `iosTests/History/HistoryViewModelTests.swift`
