# CLAUDE.md — TennisCounter (Ralli)

**공통 규약(작업 방식·Git Workflow·빌드 개요·YJKit 사용법)은 저장소 루트 `CLAUDE.md` 를 먼저 본다.**
이 문서는 이 앱 고유 내용만 다룬다. 사용자에게 보이는 앱 이름은 `Ralli` 다.

## Build Commands

루트에서 실행한다. 시뮬레이터 지정 규칙은 루트 `CLAUDE.md` 참조.

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')

# iOS 앱 (test 로 바꾸면 RalliTests 실행)
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" \
  -destination "id=$IOS" build

# Watch 앱 (test 로 바꾸면 RalliTests + RalliWatchTests 실행)
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" \
  -destination "id=$WATCH" build

# Complication 위젯
xcodebuild -workspace YJApps.xcworkspace -scheme "RalliComplicationExtension" \
  -destination "id=$WATCH" build

# Live Activity
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisLiveActivityExtension" \
  -destination "id=$IOS" build
```

> 스킴은 `RalliComplicationExtension` 이지만 타깃 이름은 `ComplicationAppExtension` 이다
> (출시 산출물명 유지 목적). 테스트 타깃은 `RalliTests` / `RalliWatchTests`.

## Architecture

Tennis score tracking app (Ralli) with three targets sharing a single model. Feature-based folder structure with MVVM pattern. Each top-level folder is a domain feature; sub-folders are screens within that feature.

```
Shared/
│  # iOS/Watch 두 타겟이 공유하는 코드. 플랫폼 독립적인 순수 로직만 둔다.
├── Models/
│   ├── Score.swift          # 점수 상태 ObservableObject. scoreArr = [0,15,30,40,50], Snapshot 왕복 API 제공
│   ├── MatchFormat.swift    # 경기 포맷 (세트 수, 타이브레이크 등)
│   ├── MatchOptions.swift   # 경기 옵션 (포맷 + 모드 조합)
│   ├── MatchPhase.swift     # 경기 진행 단계 enum (mode → playing → result)
│   ├── MatchResult.swift    # 경기 결과 struct
│   ├── MatchSession.swift   # 진행 중 경기 세션 상태
│   └── SetScore.swift       # 세트 점수 struct
│   # 워크아웃 메트릭(WorkoutMetrics)은 YJKit WorkoutCore 타입을 쓴다 — 앱에 정의하지 않는다
├── Persistence/
│   │  # SwiftData @Model 클래스. DB 스키마 역할.
│   ├── Match.swift          # SwiftData 경기 기록 모델
│   └── SetRecord.swift      # 세트별 기록 struct
└── Services/
    │  # 외부 프레임워크/시스템 API를 래핑하는 서비스 레이어.
    ├── ConnectivityMessages.swift      # 워치↔폰 메시지 정의 (ConnectivityMessage 채택)
    └── MatchConnectivity.swift         # 폰↔워치 실시간 점수·워크아웃 앵커 동기화 + pause 명령 왕복 (YJKit ConnectivityCore/WorkoutCore 기반)

iOSApp/
│  # iPhone 전용 타겟
├── iOSApp.swift           # @main 진입점 + MainTabView
├── BrandColor.swift       # Color.brand 확장 (앱 브랜드 컬러)
├── Extensions/
│   └── Date+Month.swift   # Date 월 표기 헬퍼
├── Services/
│   ├── LiveActivityService.swift  # Live Activity 시작/업데이트/종료
│   └── MatchPersistenceService.swift  # SwiftData 경기 저장/조회 (YJKit PersistenceCore 위임)
├── Components/
│   ├── BackButton.swift   # 공통 뒤로가기 버튼
│   ├── BrandTitle.swift   # 앱 브랜드 타이틀 컴포넌트
│   ├── MatchCard.swift    # Summary·History 공유 경기 카드
│   └── StatCard.swift     # 통계 수치 카드 (Summary·History 공유)
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
    ├── WorkoutSession/                  # iOS 워크아웃 세션 컨테이너
    │   │  # 2-탭 TabView [Workout | Match]. 워크아웃 탭 화면은 YJKit WorkoutUI(WorkoutDashboardView)가 소유
    │   ├── WorkoutSessionView.swift
    │   ├── WorkoutSessionViewModel.swift  # 경과시간은 워치 앵커 기반 보간(WorkoutAnchor). pause는 왕복 요청만 보내고 ack 전엔 낙관적으로 토글하지 않음
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
    └── WorkoutSession/
        │  # 컨테이너 Feature: 3-탭 TabView [WorkoutControlsView | Match | WorkoutMetricsView]
        │  # 좌우 두 탭 화면은 YJKit WorkoutUI가 소유 — 앱에 워크아웃 UI를 두지 않는다
        │  # HealthKit 세션 생명주기 관리, Match 흐름 조정
        ├── WorkoutSessionView.swift      # 좌우 스와이프로 3개 탭 전환
        ├── WorkoutSessionViewModel.swift # MatchPhase 상태 + HealthKit 연동. 폰의 pause 명령 수신 → HKWorkoutSession 제어, 워크아웃 누적 메트릭을 앵커로 브로드캐스트
        └── WorkoutConfiguration+Tennis.swift # 테니스 종목 설정 (YJKit WorkoutConfiguration 주입값)

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

- **Score** (`ObservableObject`): point state (`scoreArr = [0, 15, 30, 40, 50]`), 복원용 `Score.Snapshot` 왕복 API 제공. undo 스택은 `ScoreViewModel`이 소유한다 (경기 전체 되돌리기). iOS/Watch 타겟 공유.
- **ScoreViewModel**: `Score` 인스턴스를 소유, 게임/세트 레벨 로직 담당. iOS·Watch 모두 `Match/Score/ScoreViewModel.swift`에 위치.
- **ScoreView**: `ScoreViewModel`을 바인딩. 경기 종료 시 `MatchResultView`로 전환.
- **Shared/Persistence/**: SwiftData `@Model` 클래스. `MatchPersistenceService`를 통해서만 접근.
- **Roadmap**: Phase 1-A (SwiftData + WatchConnectivity) 구현 완료. Phase 1-B에서 HealthKit + Live Activity. Phase 2에서 Firebase 멀티 모드 + StoreKit 2.

## YJKit 의존성

인프라 계층은 모노레포의 로컬 패키지 `Packages/YJKit` 이다. 프로덕트 구성·워크아웃 동작 계약은
루트 `CLAUDE.md` 와 `Packages/YJKit/README.md` 를 본다.

**앱 레이어가 소유하는 것** — 코어는 도메인을 모른다.

- `Shared/Services/MatchConnectivity.swift` — 코어의 1회성 핸들러를 sticky `@Published`로 복원하는 앱 래퍼
- `Shared/Services/ConnectivityMessages.swift` — 테니스 도메인 메시지 (`ConnectivityMessage` 채택)
- `iOSApp/Services/MatchPersistenceService.swift` — 중복 제거·정렬 규칙. CRUD는 `PersistenceCore`에 위임 (Watch는 저장소를 쓰지 않아 `Shared/`가 아닌 `iOSApp/`에 둔다)
- `WatchApp/Features/WorkoutSession/WorkoutConfiguration+Tennis.swift` — 종목 설정 주입값

## Folder Conventions

폴더·컴포넌트 계층·Import·네이밍 컨벤션은 루트 `CLAUDE.md` 의 **앱 코드 컨벤션**을 따른다. 이 앱의 예외는 없다.

## Docs Conventions

- `docs/specs/` 와 `docs/plans/` 파일은 **최종 완료된 상태에서만 커밋**한다.
- 작성 중인 스펙/계획은 커밋하지 않는다.
- **스킬이 커밋을 지시하더라도 사용자 검토 전에는 커밋하지 않는다.**

폴더 구조와 파일명 규칙은 루트 `CLAUDE.md` 의 "Docs 공통 규약" 을 따른다.

- `ideas/` 는 검토 중 문서이므로 커밋 여부는 사용자 판단에 따른다 (기본은 미커밋).

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
│   └── ScoreViewModelTests.swift        # iOSApp/Features/Match/Score/ 대응
├── History/
│   └── HistoryViewModelTests.swift      # iOSApp/Features/History/ 대응
├── Summary/
│   └── SummaryViewModelTests.swift      # iOSApp/Features/Summary/ 대응
├── WorkoutSession/
│   └── WorkoutSessionViewModelTests.swift  # iOSApp/Features/WorkoutSession/ 대응
├── Services/
│   └── MatchPersistenceServiceTests.swift  # iOSApp/Services/ 대응
└── Shared/                              # Shared/Models·Services 대응
    ├── ScoreTests.swift
    ├── ConnectivityMessagesTests.swift
    ├── MatchConnectivityTests.swift
    ├── MatchEndMessageTests.swift
    └── MatchSaveResultMessageTests.swift

watchosTests/
├── Match/
│   └── ScoreViewModelTests.swift        # WatchApp/Features/Match/Score/ 대응
└── WorkoutSession/
    └── WorkoutSessionViewModelTests.swift  # WatchApp/Features/WorkoutSession/ 대응
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
