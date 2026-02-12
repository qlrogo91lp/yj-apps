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

Tennis score tracking app with three targets sharing a single model. MVVM 패턴으로 화면 단위(Feature) 폴더 구성.

```
Shared/Models/Score.swift              # ObservableObject, point state + undo
iOSApp/
├── iOSApp.swift                       # @main → MatchView()
└── Screens/Match/
    ├── MatchView.swift                # 메인 스코어 화면
    ├── MatchViewModel.swift           # 게임 로직 (confirmScore, resetAll)
    └── Components/CounterButtonView.swift  # +/- 버튼 컴포넌트
WatchApp/
├── WatchApp.swift                     # @main → HomeView()
└── Screens/
    ├── Home/HomeView.swift            # 홈 (Quick Match 진입)
    └── Match/
        ├── MatchView.swift            # 터치 스코어링 화면
        └── MatchViewModel.swift       # 게임/세트 로직 (addPoint, undo, checkGameUpdate)
ComplicationApp/                       # watchOS widget/complication (WidgetKit + AppIntents)
```

- **Score** (`ObservableObject`): point state (`scoreArr = [0, 15, 30, 40, 50]`), undo via `LastAction` enum. iOS/Watch 타겟 공유.
- **MatchViewModel**: `Score` 인스턴스를 `@Published`로 소유, 게임/세트 레벨 로직 담당.
- **View**: `@StateObject var viewModel = MatchViewModel()`으로 ViewModel 바인딩. Game win at 50 points (index 4), set win at 6 games.

## Conventions

- Colors are inline (green=ME, orange=OPP) — no centralized theme system
- SwiftLint: line length 150/200, disabled `trailing_comma`, `todo`, `opening_brace`
- SwiftFormat: 4-space indent, max width 150, alphabetical imports
