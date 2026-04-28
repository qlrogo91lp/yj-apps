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

# Lint & Format
make lint      # Run swiftlint
make format    # SwiftFormat --lint check
make fix       # Auto-fix: swiftformat + swiftlint --fix
```

No test targets exist in this project.

## Architecture

Tennis score tracking app (Ralli) with three targets sharing a single model. Feature-based folder structure with MVVM pattern. Each top-level folder is a domain feature; sub-folders are screens within that feature.

```
Shared/
│  # iOS/Watch 두 타겟이 공유하는 코드. 플랫폼 독립적인 순수 로직만 둔다.
├── Models/
│   └── Score.swift        # 점수 상태 ObservableObject. scoreArr = [0,15,30,40,50], undo via LastAction enum
└── Services/
    │  # 외부 프레임워크/시스템 API를 래핑하는 서비스 레이어. Phase 1+에서 파일 추가 예정.
    ├── HealthKitService.swift       # (Phase 1-B) 워크아웃 세션, 칼로리/BPM 측정
    ├── WatchConnectivityService.swift  # (Phase 1-A) 폰↔워치 실시간 점수 동기화
    └── CloudKitService.swift        # (Phase 1-A) SwiftData + iCloud 경기 기록 동기화

iOSApp/
│  # iPhone 전용 타겟
├── iOSApp.swift           # @main 진입점, 3-탭 TabView로 구성 예정
└── Features/
    │  # 도메인/기능 단위 폴더. 탭 하나 = Feature 하나가 기본 원칙.
    ├── Summary/
    │   │  # 요약 탭 — 오늘/주간 통계, streak, 최근 경기 카드 (Phase 1-A)
    │   ├── SummaryView.swift
    │   └── SummaryViewModel.swift
    ├── Match/
    │   │  # 경기 탭 — 모드 선택부터 점수 입력까지의 흐름을 담는 Feature
    │   ├── ModeSelection/
    │   │   │  # 경기 시작 전 포맷 선택 화면 (One Set / Best of 3) (Phase 1-A)
    │   │   ├── ModeSelectionView.swift
    │   │   └── ModeSelectionViewModel.swift
    │   └── Score/
    │       │  # 실제 점수 입력 화면. 모드에 따라 세트 인디케이터 표시 여부 분기
    │       ├── MatchView.swift
    │       ├── MatchViewModel.swift   # confirmScore, resetAll, 게임/세트 집계
    │       └── Components/
    │           │  # Score 화면 전용 재사용 UI 컴포넌트
    │           └── CounterButtonView.swift  # +/- 점수 버튼
    └── History/
        │  # 기록 탭 — 저장된 경기 히스토리, 달력/리스트 토글 (Phase 1-A)
        ├── HistoryView.swift
        └── HistoryViewModel.swift

WatchApp/
│  # Apple Watch 전용 타겟. 좌우 스와이프 페이지 구조 (Phase 1-B).
├── WatchApp.swift         # @main 진입점 → HomeView()
└── Features/
    ├── Home/
    │   │  # 워치 홈 화면 — Quick Match 진입 버튼
    │   └── HomeView.swift
    └── Match/
        │  # 경기 중 워치 화면. 스와이프로 페이지 전환 (Phase 1-B: Score/Exercise/History 3페이지)
        ├── MatchView.swift        # 터치 스코어링 (탭으로 득점 입력)
        └── MatchViewModel.swift   # addPoint, undo, checkGameUpdate, 세트 집계

ComplicationApp/
│  # watchOS WidgetKit complication + AppIntents. 잠금화면/항상켜기 화면에 현재 점수 표시.
└── ...
```

- **Score** (`ObservableObject`): point state (`scoreArr = [0, 15, 30, 40, 50]`), undo via `LastAction` enum. iOS/Watch 타겟 공유.
- **MatchViewModel**: `Score` 인스턴스를 `@Published`로 소유, 게임/세트 레벨 로직 담당.
- **View**: `@StateObject var viewModel = MatchViewModel()`으로 ViewModel 바인딩. Game win at 50 points (index 4), set win at 6 games.
- **Roadmap**: Phase 1-A에서 3-탭(Summary/Match/History) + SwiftData + WatchConnectivity. Phase 1-B에서 HealthKit + Live Activity. Phase 2에서 Firebase 멀티 모드 + StoreKit 2.

## Folder Conventions

| 폴더 | 무엇을 두는가 | 두지 않는 것 |
|------|-------------|-------------|
| `Features/` | 탭 또는 도메인 단위 기능. View + ViewModel 한 쌍이 기본. 하위에 화면 단위 서브폴더 허용. | 여러 Feature에서 공유되는 UI → `Components/` (앱 전역) |
| `Features/X/Components/` | 해당 Feature 전용 재사용 UI 컴포넌트. 다른 Feature에서 import하면 안 됨. | 비즈니스 로직, ViewModel |
| `Shared/Models/` | 플랫폼 독립 데이터 모델. SwiftData `@Model` 클래스, 순수 struct/enum. iOS·Watch 양쪽에서 쓰는 것만. | UI 코드, 프레임워크 의존 코드 |
| `Shared/Services/` | 시스템 프레임워크(HealthKit, WatchConnectivity, CloudKit, Firebase 등) 래퍼. 호출부가 프레임워크 API를 직접 참조하지 않도록 추상화. | View, ViewModel, 데이터 모델 |

**파일 배치 판단 기준**

- 두 Feature 이상에서 같은 컴포넌트가 필요해지면 → 앱 루트 `Components/` 폴더로 승격
- 시스템 API 호출이 ViewModel에 직접 들어가면 → Services로 분리
- Model이 특정 Feature에서만 쓰인다면 → 그래도 `Shared/Models/`에 둔다 (나중에 Watch 공유 가능성)

## Code Conventions

- Colors are inline (green=ME, orange=OPP) — no centralized theme system
- SwiftLint: line length 150/200, disabled `trailing_comma`, `todo`, `opening_brace`
- SwiftFormat: 4-space indent, max width 150, alphabetical imports
