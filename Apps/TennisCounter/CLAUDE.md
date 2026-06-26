# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build iOS app
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Build Watch app
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build

# Build Complication widget
xcodebuild -project TennisCounter.xcodeproj -scheme "ComplicationAppExtension" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build

# Run iOS tests
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Run Watch tests
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,id=8502B1AE-7DCB-4442-9D80-FD34FD0370E1'

# Lint & Format
make lint      # Run swiftlint
make format    # SwiftFormat --lint check
make fix       # Auto-fix: swiftformat + swiftlint --fix
```

## Architecture

Tennis score tracking app (Ralli) with three targets sharing a single model. Feature-based folder structure with MVVM pattern. Each top-level folder is a domain feature; sub-folders are screens within that feature.

```
Shared/
│  # iOS/Watch 두 타겟이 공유하는 코드. 플랫폼 독립적인 순수 로직만 둔다.
├── Models/
│   ├── Score.swift          # 점수 상태 ObservableObject. scoreArr = [0,15,30,40,50], undo via LastAction enum
│   ├── MatchFormat.swift    # 경기 포맷 (세트 수, 타이브레이크 등)
│   ├── MatchOptions.swift   # 경기 옵션 (포맷 + 모드 조합)
│   ├── MatchPhase.swift     # 경기 진행 단계 enum (mode → playing → result)
│   ├── MatchResult.swift    # 경기 결과 struct
│   ├── MatchSession.swift   # 진행 중 경기 세션 상태
│   ├── SetScore.swift       # 세트 점수 struct
│   └── WorkoutMetrics.swift # HealthKit 메트릭 (칼로리, BPM, 시간)
├── Persistence/
│   │  # SwiftData @Model 클래스. DB 스키마 역할.
│   ├── Match.swift          # SwiftData 경기 기록 모델
│   └── SetRecord.swift      # 세트별 기록 struct
└── Services/
    │  # 외부 프레임워크/시스템 API를 래핑하는 서비스 레이어.
    ├── HealthKitService.swift          # 워크아웃 세션, 칼로리/BPM 측정
    ├── MatchPersistenceService.swift   # SwiftData 경기 저장/조회
    └── WatchConnectivityService.swift  # 폰↔워치 실시간 점수 동기화

iOSApp/
│  # iPhone 전용 타겟
├── iOSApp.swift           # @main 진입점 + MainTabView
├── BrandColor.swift       # Color.brand 확장 (앱 브랜드 컬러)
├── Extensions/
│   └── Date+Month.swift   # Date 월 표기 헬퍼
├── Services/
│   └── LiveActivityService.swift  # Live Activity 시작/업데이트/종료
├── Components/
│   ├── BackButton.swift   # 공통 뒤로가기 버튼
│   ├── BrandTitle.swift   # 앱 브랜드 타이틀 컴포넌트
│   ├── MatchCard.swift    # Summary·History 공유 경기 카드
│   └── StatCard.swift     # 통계 수치 카드 (Summary·Workout 공유)
└── Features/
    ├── Home/
    │   └── HomeView.swift           # iOS 홈 화면 (탭 컨테이너)
    ├── Launch/
    │   └── LaunchScreenView.swift   # 런치 스크린
    ├── Summary/
    │   ├── SummaryView.swift
    │   ├── SummaryViewModel.swift
    │   └── Components/
    │       ├── MatchStatsGrid.swift   # 경기 통계 그리드
    │       ├── RecentMatchList.swift  # 최근 경기 목록
    │       └── WorkoutStatsGrid.swift # 워크아웃 통계 그리드
    ├── Match/
    │   │  # Watch 앱과 대칭 구조: Mode / Score / Result
    │   ├── Mode/                        # 포맷 선택 화면
    │   │   ├── ModeView.swift
    │   │   ├── ModeViewModel.swift
    │   │   └── Components/
    │   │       └── ModeOptionItem.swift
    │   ├── Score/                       # 점수 입력 화면
    │   │   ├── ScoreView.swift
    │   │   ├── ScoreViewModel.swift
    │   │   └── Components/
    │   │       ├── PlayerPointZone.swift
    │   │       ├── GameScores.swift
    │   │       ├── SetScores.swift
    │   │       ├── UndoButton.swift
    │   │       └── ScoreEditSheet.swift
    │   └── Result/                      # 경기 결과 화면
    │       ├── MatchResultView.swift
    │       └── Components/
    │           ├── RematchButton.swift
    │           └── SaveButton.swift
    ├── Workout/                         # 워크아웃 메트릭 탭 (iOS 전용)
    │   ├── WorkoutTabView.swift
    │   └── Components/
    │       ├── HeartRateIcon.swift
    │       ├── MetricCard.swift
    │       ├── WorkoutControls.swift
    │       ├── WorkoutMetricsGrid.swift
    │       └── WorkoutTimerRing.swift
    ├── WorkoutSession/                  # iOS 워크아웃 세션 컨테이너
    │   ├── WorkoutSessionView.swift
    │   ├── WorkoutSessionViewModel.swift
    │   └── Components/
    │       └── WorkoutIndicator.swift   # 경기 중 툴바에 표시되는 운동 경과시간
    └── History/
        ├── HistoryView.swift
        ├── HistoryViewModel.swift
        ├── Calendar/                    # 캘린더 뷰 서브 피처
        │   ├── CalendarView.swift
        │   └── Components/
        │       ├── CalendarGrid.swift
        │       ├── DayCell.swift
        │       ├── MonthHeader.swift
        │       └── WeekdayLabels.swift
        └── Components/
            ├── HistoryEmptyState.swift  # 기록 없을 때 빈 상태 뷰
            ├── MatchDetailSheet.swift   # 경기 상세 시트
            └── MatchList.swift          # 경기 목록

WatchApp/
│  # Apple Watch 전용 타겟. HealthKit 통합 Workout 경험 제공.
├── WatchApp.swift         # @main 진입점 → HomeView()
├── Components/
│   └── BackButton.swift   # 공통 뒤로가기 버튼
└── Features/
    ├── Home/
    │   └── HomeView.swift           # 워치 홈 화면 — Workout 진입 버튼
    ├── Match/
    │   │  # 경기 도메인 (Workout과 독립적). 모드 선택 → 점수 입력 → 결과
    │   ├── Mode/                        # 포맷 선택 화면
    │   │   ├── ModeView.swift
    │   │   ├── ModeViewModel.swift
    │   │   └── Components/
    │   │       └── ModeOptionItem.swift
    │   ├── Score/                       # 점수 입력 화면
    │   │   ├── ScoreView.swift
    │   │   ├── ScoreViewModel.swift
    │   │   └── Components/
    │   │       ├── GameScores.swift
    │   │       ├── SetScores.swift
    │   │       ├── PlayerPointButton.swift
    │   │       └── UndoButton.swift
    │   └── Result/                      # 경기 결과 화면
    │       ├── MatchResultView.swift
    │       └── Components/
    │           ├── RematchButton.swift
    │           └── SaveButton.swift
    ├── Workout/
    │   │  # HealthKit 통합 전용 UI (제어, 메트릭 표시)
    │   ├── Controls/                    # 일시정지/재개/종료 버튼
    │   │   ├── WorkoutControlsView.swift
    │   │   └── Components/
    │   │       ├── WorkoutPauseButton.swift
    │   │       └── WorkoutEndButton.swift
    │   └── Metrics/                     # 칼로리/BPM/시간 표시
    │       ├── WorkoutMetricsView.swift
    │       └── Components/
    │           └── WorkoutMetric.swift
    └── WorkoutSession/
        │  # 컨테이너 Feature: 3-탭 TabView [Workout.Controls | Match | Workout.Metrics]
        │  # HealthKit 세션 생명주기 관리, Match 흐름 조정
        ├── WorkoutSessionView.swift      # 좌우 스와이프로 3개 탭 전환
        └── WorkoutSessionViewModel.swift # MatchPhase 상태 + HealthKit 연동

ComplicationApp/
│  # watchOS WidgetKit complication + AppIntents. 잠금화면/항상켜기 화면에 현재 점수 표시.
└── ...

TennisLiveActivity/
│  # iOS Live Activity 위젯 익스텐션. 잠금화면/Dynamic Island에 실시간 점수 표시.
├── TennisLiveActivityBundle.swift  # WidgetBundle 진입점
├── TennisLiveActivityView.swift    # Live Activity 메인 뷰
├── BrandColor.swift                # Color.brand 확장 (익스텐션 타겟용)
├── Models/
│   └── TennisActivityAttributes.swift  # ActivityAttributes 정의
└── Components/
    └── LiveActivityView.swift      # 잠금화면/Dynamic Island 레이아웃
```

- **Score** (`ObservableObject`): point state (`scoreArr = [0, 15, 30, 40, 50]`), undo via `LastAction` enum. iOS/Watch 타겟 공유.
- **ScoreViewModel**: `Score` 인스턴스를 소유, 게임/세트 레벨 로직 담당. iOS·Watch 모두 `Match/Score/ScoreViewModel.swift`에 위치.
- **ScoreView**: `ScoreViewModel`을 바인딩. 경기 종료 시 `MatchResultView`로 전환.
- **Shared/Persistence/**: SwiftData `@Model` 클래스. `MatchPersistenceService`를 통해서만 접근.
- **Roadmap**: Phase 1-A (SwiftData + WatchConnectivity) 구현 완료. Phase 1-B에서 HealthKit + Live Activity. Phase 2에서 Firebase 멀티 모드 + StoreKit 2.

## Folder Conventions

| 폴더 | 무엇을 두는가 | 두지 않는 것 |
|------|-------------|-------------|
| `Features/` | 탭 또는 도메인 단위 기능. View + ViewModel 한 쌍이 기본. 하위에 화면 단위 서브폴더 허용. | 여러 Feature에서 공유되는 UI → `Components/` (앱 전역) |
| `Features/X/Components/` | 해당 Feature 전용 재사용 UI 컴포넌트. 다른 Feature에서 import하면 안 됨. | 비즈니스 로직, ViewModel |
| `Features/X/ScreenName/Components/` | 특정 View 전용 순수 컴포넌트. 같은 폴더의 View에서만 import. | 다른 View에서 공유 컴포넌트 |
| `Shared/Models/` | 플랫폼 독립 데이터 모델. SwiftData `@Model` 클래스, 순수 struct/enum. iOS·Watch 양쪽에서 쓰는 것만. | UI 코드, 프레임워크 의존 코드 |
| `Shared/Services/` | 시스템 프레임워크(HealthKit, WatchConnectivity, CloudKit, Firebase 등) 래퍼. 호출부가 프레임워크 API를 직접 참조하지 않도록 추상화. | View, ViewModel, 데이터 모델 |

**파일 배치 판단 기준 (계층화된 컴포넌트 구조)**

모듈화 원칙: 각 계층은 하위 계층으로만 의존하고, 상위 계층에서는 import하지 않음.

```
앱 루트 Components/  ← 두 Feature 이상이 공유하는 컴포넌트 (가장 재사용 가능)
    ↑
Features/X/Components/  ← Feature 내 여러 View가 공유 (Feature 독립적)
    ↑
ScreenName/Components/  ← 특정 View 전용 (가장 낮은 계층)
```

- 특정 View 전용 순수 컴포넌트 → `ScreenName/Components/` 에 배치
- Feature 내 여러 View에서 공유 → `Features/X/Components/` 에 배치
- 두 Feature 이상에서 필요 → 앱 루트 `Components/` 폴더로 승격 (재사용을 목표로)
- 시스템 API 호출 → `Shared/Services/` 로 분리 (ViewModel은 순수 로직만)
- Model이 특정 Feature 전용이어도 → 그래도 `Shared/Models/`에 둔다 (플랫폼 공유 가능성)

**Import 규칙 (순환 의존성 금지)**

- `ScreenName/Components/` → 상위 폴더의 View/ViewModel import 금지
- `Features/X/Components/` → 다른 Feature import 금지
- Feature → Shared만 import 가능
- ViewModel → UI 프레임워크 import 금지 (순수 비즈니스 로직)

## Docs Conventions

- `docs/superpowers/specs/` 와 `docs/superpowers/plans/` 파일은 **최종 완료된 상태에서만 커밋**한다.
- 작성 중인 스펙/계획은 커밋하지 않는다.
- **스킬이 커밋을 지시하더라도 사용자 검토 전에는 커밋하지 않는다.**

**폴더 구조**

플랫폼별로 서브폴더를 나눈다. 파일명에 플랫폼을 명시하지 않아도 된다 (폴더로 구분).

```
docs/superpowers/
├── specs/
│   ├── ios/     # iOS 앱 관련 스펙
│   └── watch/   # Watch 앱 관련 스펙
├── plans/
│   ├── ios/     # iOS 앱 관련 구현 계획
│   └── watch/   # Watch 앱 관련 구현 계획
└── logs/        # 버그 수정·리팩터링 작업 기록
```

**logs 폴더**

버그 수정, 리팩터링, 주요 변경 사항의 원인·분석·수정 내용을 기록한다. 커밋 메시지로 담기 어려운 맥락(재현 경로, 근본 원인 분석, before/after 코드 비교)을 보존하는 것이 목적이다.

- 파일명: `YYYY-MM-DD-{설명}.md` (e.g., `2026-05-29-workout-connectivity-bug-fix.md`)
- 플랫폼 구분 없이 `logs/` 아래 flat하게 둔다 (한 작업이 여러 타겟에 걸치는 경우가 많으므로)
- logs 파일은 완료된 작업만 커밋한다

## Xcode 프로젝트 파일

이 프로젝트는 **Xcode 16의 `PBXFileSystemSynchronizedRootGroup`** 방식을 사용한다.

- Swift 파일을 생성하거나 삭제하면 Xcode가 폴더를 자동 스캔해서 빌드 대상에 포함/제외한다.
- `.xcodeproj/project.pbxproj`를 직접 수정하거나 `xcodeproj` gem 등 프로젝트 파일 편집 도구를 사용할 필요가 없다.
- 파일 이동/생성/삭제는 파일시스템 조작만으로 충분하다.

## Testing

기능 추가나 버그 수정 시 **반드시 테스트를 함께 작성**한다.

**프레임워크**: Swift Testing (`@Test`, `#expect`, `Issue.record`)

**파일 위치**

테스트 타겟은 앱 타겟과 빌드가 분리되므로, 소스 파일과 같은 폴더에 둘 수 없다. 대신 테스트 폴더 안에서 소스 폴더 구조를 그대로 미러링한다.

| 대상 | 테스트 루트 |
|------|-----------|
| iOS 타겟 (`TennisCounter`) | `iosTests/` |
| Watch 타겟 (`TennisCounter Watch App`) | `watchosTests/` |

```
iosTests/
├── Match/
│   ├── ScoreViewModelTests.swift        # iOSApp/Features/Match/Score/ 대응
│   └── WorkoutSessionViewModelTests.swift
└── Shared/
    └── WorkoutMetricsTests.swift        # Shared/Models/ 대응

watchosTests/
└── Match/
    └── ScoreViewModelTests.swift        # WatchApp/Features/Match/Score/ 대응
```

- 파일명: `{테스트대상}Tests.swift` (e.g., `ScoreViewModelTests.swift`)
- 서브폴더는 `PBXFileSystemSynchronizedRootGroup` 덕분에 Xcode가 자동으로 테스트 타겟에 포함한다.

**테스트 대상 우선순위**

1. **ViewModel** — 비즈니스 로직의 핵심. 반드시 테스트.
2. **Service** — 메시지 파싱, 데이터 변환 등 순수 로직 부분.
3. **Model** — `toDictionary()` / `init?(from:)` 같은 직렬화 로직.
4. **View** — 테스트하지 않는다. UI는 직접 확인.

**작성 규칙**

- ViewModel 테스트는 `@MainActor` 필수
- 테스트명: `대상_행위_예상결과` 형태 (e.g., `addPointWinsGame`, `endSessionResetsState`)
- 하나의 `@Test` 는 하나의 시나리오만 검증
- 외부 의존성(HealthKit, WatchConnectivity)은 테스트에서 직접 호출하지 않음 — ViewModel의 순수 상태 변화만 검증

**버그 수정 시**: 해당 버그를 재현하는 테스트를 먼저 작성한 뒤 수정한다.

## Code Conventions

- Brand color: `Color.brand` (`BrandColor.swift`). Player colors are inline (green=ME, orange=OPP)
- SwiftLint: line length 150/200, disabled `trailing_comma`, `todo`, `opening_brace`
- SwiftFormat: 4-space indent, max width 150, alphabetical imports

**Modularity & Separation of Concerns**
- **ViewModel**: 비즈니스 로직만 담당. SwiftUI 프레임워크 import 금지, `@Published` 속성만 노출
- **View**: 표현(UI 렌더링)만 담당. 비즈니스 로직은 ViewModel으로 위임
- **Component**: 단일 책임 원칙. 한 파일은 한 UI 단위만 정의. Props drilling 최소화
- **Service**: 시스템/외부 API 호출을 캡슐화. 호출부는 Service 인터페이스만 알게 함

**File Naming**
- View suffix: 독립적인 화면/페이지만 (e.g., `ModeView.swift`, `MatchView.swift`, `WorkoutSessionView.swift`)
- Components 폴더의 순수 컴포넌트: suffix 없음 (e.g., `UndoButton.swift`, `GameScores.swift`, `PlayerPointButton.swift`)
- 한 파일 = 한 타입: 같은 파일에 여러 View/ViewModel 정의 금지 (단, private helper component는 제외)

## Git Workflow

PR 머지 시 squash 금지. 항상 일반 merge commit을 사용한다.

```bash
gh pr merge <number> --merge --delete-branch
```
