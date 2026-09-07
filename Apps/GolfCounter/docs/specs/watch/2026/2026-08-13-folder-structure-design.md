# WatchApp 폴더 구조 개편 설계

- 작성일: 2026-08-13
- 참조: `2026-07-31-golfcounter-rebuild-design.md` §2, `2026-08-11-watch-counter-redesign-design.md`, CLAUDE.md 폴더별 배치 기준
- 범위: `WatchApp/` 폴더 재배치·리네임 + `watchosTests/` 미러링 + 스펙 2건 경로 개정. **동작 변경 0** — diff는 전부 이동/이름/추출이다.

## 1. 문제

카운터 재설계(2026-08-11)를 거치며 `Features/Round/Counter/Components/`가 성격이 다른 파일들의 서랍이 됐고, 이름의 역할 표기가 실제와 어긋났다.

1. **이름 역전**: 실제 카운터 화면은 `CounterPage`(Components 안, `@ObservedObject viewModel` 수신·햅틱 호출)이고, `CounterView`는 자기 UI가 없는 세로 페이징 껍데기다. 화면인 쪽이 Page, 껍데기인 쪽이 View를 갖고 있다. 프로젝트 규칙상 화면 단위는 View suffix이므로 Page suffix는 존재 자체가 규칙 위반이다.
2. **Components 오염**: `ScreenName/Components/`는 "순수 컴포넌트" 자리인데, 화면급인 `CounterPage`·`Scorecard`와 순수 계산 타입인 `RingSegments`·`ScorecardChunks`·`CounterSizing`(셋 다 UI 프레임워크 미import, 각자 테스트 보유)이 들어와 있다.
3. **세션 페이지의 층위 불일치**: 사용자가 스와이프·크라운으로 넘기는 페이지 5개(Controls·ParSelection·Counter·Scorecard·Metrics)가 세 가지 다른 대우를 받는다 — ParSelection만 폴더, Counter·Scorecard는 Components 안, Controls·Metrics는 `RoundSessionView`에 인라인.
4. **워치 전용 어댑터 자리 부재**: `WorkoutConfiguration+Golf.swift`(HealthKit 설정)가 `Features/Round/` 루트에 있다. `Shared/`로 못 옮긴다 — Shared 그룹은 iOS 타깃에도 링크되어 `import WorkoutCore`가 iOS 빌드를 깨기 때문(전송 플랜 §0 확인 사항). 미구현 플랜 ④가 같은 성격의 `RoundMetrics+WorkoutResult.swift`를 또 Feature 폴더에 추가할 예정이라, 자리를 만들지 않으면 어댑터가 계속 쌓인다.
5. **테스트 미러링 위반**: 소스는 `Features/Round/Counter/`로 중첩인데 `watchosTests/Round/`는 7개 파일이 평평하다.

pbxproj는 `PBXFileSystemSynchronizedRootGroup`이고 WatchApp 그룹에 멤버십 예외가 없어, **재배치에 pbxproj 수정이 필요 없다.** SwiftLint `included:`도 최상위 폴더 단위라 영향 없다.

## 2. 원칙

- **세션 페이지 = 폴더 하나 + `~View` 하나.** 사용자가 실제로 넘겨보는 단위가 코드 구조의 단위다. 가로 3페이지(SessionControls · ParSelection/Counting · SessionMetrics)와 세로 페이지(Counting · Scorecard) 전부에 적용한다.
- **`Components/`에는 뷰모델을 모르는 순수 View만.** 계산 타입과 화면은 화면 폴더 루트로 올린다.
- **컴포넌트 이름은 접두 통일이 아니라 기능으로 짓는다.** `ModeButton`·`UndoButton`·`StrokeRing`이 이미 그렇다. `CounterHeader`·`CounterControls`의 Counter 접두는 관례가 아니라 흔적이므로 기능에 맞는 이름으로 바꾼다.
- **동작 변경 0.** 로직 수정·리팩터링은 이번 범위가 아니다. 빌드 + 기존 테스트 통과가 그대로 검증이 된다.

## 3. 최종 구조

```
WatchApp/
├── WatchApp.swift
├── Services/                                ← 신설: 워치 전용 시스템 프레임워크 어댑터
│   └── WorkoutConfiguration+Golf.swift
└── Features/
    ├── Home/
    │   └── HomeView.swift                   (이번 범위에서 변경 없음)
    └── Round/
        ├── RoundSessionView.swift           가로 3페이지 컨테이너 (조립 + 워크아웃 수명주기)
        ├── RoundViewModel.swift             (이동 없음)
        ├── ScoringView.swift                세로 N페이지 컨테이너 ← 구 CounterView
        ├── SessionControls/                 [가로 1/3]
        │   └── SessionControlsView.swift    신규 — RoundSessionView에서 추출
        ├── ParSelection/                    [가로 2/3 · phase .parSelection]
        │   ├── ParSelectionView.swift
        │   └── Components/
        │       ├── ParOptionButton.swift
        │       └── ParBackButton.swift
        ├── Counting/                        [세로 1페이지 · phase .counting]
        │   ├── CountingView.swift           ← 구 CounterPage (실제 카운터 화면)
        │   ├── CountingSizing.swift         ← 구 CounterSizing (화면 전체의 크기 세트)
        │   ├── RingSegments.swift           (순수 계산 — Components 밖)
        │   └── Components/
        │       ├── HoleHeader.swift         ← 구 CounterHeader (현재 홀 번호·파·누적 타수 행)
        │       ├── HoleNavigation.swift     ← 구 CounterControls (이전/다음 홀 이동 행)
        │       ├── ModeButton.swift
        │       ├── UndoButton.swift
        │       └── StrokeRing.swift
        ├── Scorecard/                       [세로 2~N페이지]
        │   ├── ScorecardView.swift          ← 구 Scorecard
        │   └── ScorecardChunks.swift        (순수 계산 — Components 밖)
        └── SessionMetrics/                  [가로 3/3]
            └── SessionMetricsView.swift     신규 — RoundSessionView에서 추출
```

`Round/` 루트에는 컨테이너 2개(`RoundSessionView` 가로축, `ScoringView` 세로축)와 `RoundViewModel`만 남는다. 플랜 ④의 요약 화면은 `Summary/SummaryView.swift`로 이 형제 자리에 들어온다.

### 이름 결정과 근거

| 이름 | 근거 |
|------|------|
| `ScoringView` (껍데기) | 카운터 화면과 스코어카드를 둘 다 담으므로 "점수를 기록하는 구간 전체". Counter/Counting과 아예 다른 단어라 층위 혼동이 없다. |
| `CountingView` (화면) | 실제로 세는 화면. phase enum `.counting`과 1:1이므로 **enum은 리네임하지 않는다.** |
| `HoleHeader` / `HoleNavigation` | 접두 통일 대신 기능 — 헤더는 현재 홀 정보 표시, 하단 행은 홀 이동. `HoleNavigation`은 재설계 전 실재했던 이름의 부활이지만 위치·내용은 다르다(ModeButton 슬롯 포함). |
| `SessionControlsView` / `SessionMetricsView` | `RoundSessionView`가 이미 쓰는 "세션" 어휘. `WorkoutControlsView`·`WorkoutMetricsView`(WorkoutUI 타입)와 접두로 구별된다. |
| `CountingSizing` | 헤더·링·조작행 전부의 크기를 담는 화면 단위 세트라 화면 이름을 따른다. `.regular`/`.compact`/`.tight` 케이스명과 `sizing:` 파라미터명은 유지. |

### 만들지 않는 것

- **`WatchApp/Components/`(앱 루트)**: 두 Feature가 공유하는 UI가 현재 없다. 플랜 ④에서 홀 수 선택 버튼이 `ParOptionButton`과 같은 모양으로 판명되는 시점에 승격하며 만든다.
- **`Logic/` 서브폴더**: 계산 타입은 화면 폴더 루트에 둔다. 파일 1~2개짜리 폴더를 늘리지 않는다.

## 4. 이동·리네임 매핑

| 현재 | 변경 후 | 타입명 |
|------|---------|--------|
| `Round/Counter/CounterView.swift` | `Round/ScoringView.swift` | `CounterView` → `ScoringView` |
| `Round/Counter/Components/CounterPage.swift` | `Round/Counting/CountingView.swift` | `CounterPage` → `CountingView` |
| `Round/Counter/Components/CounterSizing.swift` | `Round/Counting/CountingSizing.swift` | `CounterSizing` → `CountingSizing` |
| `Round/Counter/Components/RingSegments.swift` | `Round/Counting/RingSegments.swift` | 유지 |
| `Round/Counter/Components/CounterHeader.swift` | `Round/Counting/Components/HoleHeader.swift` | `CounterHeader` → `HoleHeader` |
| `Round/Counter/Components/CounterControls.swift` | `Round/Counting/Components/HoleNavigation.swift` | `CounterControls` → `HoleNavigation` |
| `Round/Counter/Components/ModeButton.swift` | `Round/Counting/Components/ModeButton.swift` | 유지 |
| `Round/Counter/Components/UndoButton.swift` | `Round/Counting/Components/UndoButton.swift` | 유지 |
| `Round/Counter/Components/StrokeRing.swift` | `Round/Counting/Components/StrokeRing.swift` | 유지 |
| `Round/Counter/Components/Scorecard.swift` | `Round/Scorecard/ScorecardView.swift` | `Scorecard` → `ScorecardView` |
| `Round/Counter/Components/ScorecardChunks.swift` | `Round/Scorecard/ScorecardChunks.swift` | 유지 |
| `Round/WorkoutConfiguration+Golf.swift` | `WatchApp/Services/WorkoutConfiguration+Golf.swift` | 유지 |

`Counter/` 폴더는 비워진 뒤 삭제된다.

## 5. 신규 추출 2건

`RoundSessionView`의 인라인 페이지 2개를 파일로 뽑는다. 코드 이동만, 동작 변경 없음.

**`SessionControls/SessionControlsView.swift`** — 현재 tag(0) 블록:

```swift
struct SessionControlsView: View {
    let isPaused: Bool
    let onPauseResume: () -> Void
    let onEnd: () -> Void

    var body: some View {
        WorkoutControlsView(isPaused: isPaused, onPauseResume: onPauseResume, onEnd: onEnd)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Color.clear.frame(width: 36, height: 36)
                }
            }
    }
}
```

**`SessionMetrics/SessionMetricsView.swift`** — 현재 tag(2) 블록 + `currentMetrics` 매핑:

```swift
struct SessionMetricsView: View {
    @ObservedObject var healthKit: WorkoutSessionService

    var body: some View {
        WorkoutMetricsView(metrics: metrics, isPaused: healthKit.isPaused)
    }

    private var metrics: WorkoutMetrics {
        WorkoutMetrics(elapsedSeconds: TimeInterval(healthKit.elapsedSeconds),
                       activeCalories: healthKit.currentCalories,
                       totalCalories: healthKit.currentCalories + healthKit.currentBasalCalories,
                       heartRate: healthKit.currentHeartRate)
    }
}
```

- `currentMetrics`에 붙어 있는 주석(값 타입 스냅샷 매핑의 이유, 테니스와의 차이)은 매핑을 따라 `SessionMetricsView`로 이동한다.
- `RoundSessionView`에는 TabView 조립 + phase 분기(`centerPage`) + 워크아웃 수명주기(start/end/onDisappear 방어)만 남는다.
- `healthKit`은 계속 `RoundSessionView`의 `@StateObject`가 소유하고, `SessionMetricsView`는 `@ObservedObject`로 관찰만 한다.

## 6. 테스트 미러링

| 현재 | 변경 후 |
|------|---------|
| `watchosTests/Round/CounterSizingTests.swift` | `watchosTests/Round/Counting/CountingSizingTests.swift` (타입 `CountingSizingTests`) |
| `watchosTests/Round/RingSegmentsTests.swift` | `watchosTests/Round/Counting/RingSegmentsTests.swift` |
| `watchosTests/Round/ScorecardChunksTests.swift` | `watchosTests/Round/Scorecard/ScorecardChunksTests.swift` |
| `watchosTests/Round/RoundViewModel*Tests.swift` (4개) | 유지 — 소스도 `Round/` 루트다 |

테스트 본문은 참조하는 타입명 치환(`CounterSizing` → `CountingSizing`) 외에 변경하지 않는다. `watchosTests/Shared/`의 평평한 구조는 이번 범위 밖 — iOS 작업 때 Shared 테스트 재배치와 함께 다룬다.

## 7. 문서 개정

- **리빌드 스펙 §2** (`2026-07-31-golfcounter-rebuild-design.md`): 폴더 구조 그림에 `WatchApp/Services/` 추가, `WatchApp/Components/`는 "공유 컴포넌트 발생 시 신설"로 주석, Features 아래를 새 페이지 폴더 구성으로 갱신.
- **재설계 스펙** (`2026-08-11-watch-counter-redesign-design.md`): §의 파일 경로 표를 새 경로·새 타입명으로 치환. "메인 카운터" 등 서술 어휘는 유지 — `CountingView`와 어긋나지 않는다.
- **플랜 ④** (`2026-08-05-watch-round-transmission.md`): **개정하지 않는다.** 이미 stale이며(존재하지 않는 파일 수정 지시), 후속 작업 ③에서 새 구조 기준으로 재작성이 확정이다.
- **CLAUDE.md**: 변경 없음. 이번 개편은 기존 배치 기준에 코드를 맞추는 작업이다.

## 8. 검증

동작 변경이 없으므로 아래 통과가 완료 조건이다.

1. `xcodebuild … -scheme "GolfCounter Watch App" … test` — 빌드 + watchosTests 통과
2. `xcodebuild … -scheme "GolfCounter" … build`, `-scheme "ComplicationAppExtension" … build` — 두 타깃은 WatchApp 그룹을 링크하지 않아 영향이 없어야 정상
3. `make lint` / `make format` 통과
4. `git log --follow`로 이동 파일의 히스토리 연속성 확인 (rename 감지되도록 이동과 내용 수정을 같은 커밋에서 최소화)

## 9. 후속 작업 (이번 범위 밖)

순서대로 진행하되 각각 독립된 스펙 → 플랜 → 브랜치 사이클이다. 같이 묶지 않는다 — 겹치는 파일이 `RoundViewModel` 하나뿐인데, 묶으면 구조 변경과 동작 변경이 한 diff에 섞인다.

1. **RoundViewModel 분리** — 현재 237줄. 파 선택·카운팅·홀 이동이 세 병렬 배열을 공유하므로 상태 소유권 설계가 선행돼야 한다. 별도 브레인스토밍 필요. 플랜 ④ 이전에 하는 이유: ④가 홀 수 상한·트림·전송·요약을 얹으면 350줄+가 된 뒤 나눠야 한다.
2. **플랜 ④ 재작성 → 실행** — 새 폴더 구조·분리된 ViewModel 기준으로 재작성. `HomeViewModel` 추출과 홀 수 선택 화면(`HoleCountSelection`)을 그 설계 안에서 함께 다룬다. 요약 화면은 `Round/Summary/SummaryView.swift`로 페이지 폴더 규칙을 따른다.
