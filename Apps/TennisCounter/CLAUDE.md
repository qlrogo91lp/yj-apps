# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build iOS app
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 16' build

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

Tennis score tracking app with three targets sharing a single model:

- **Shared/Models/Score.swift** — `ObservableObject` that holds point state (`scoreArr = [0, 15, 30, 40, 50]`), undo support via `LastAction` enum. Used by both iOS and Watch targets.
- **iOSApp/** — iOS interface with `CounterButtonView` component for +/- scoring
- **WatchApp/** — watchOS interface with split-screen tap regions (left=ME, right=OPP) for scoring
- **ComplicationApp/** — watchOS widget/complication (WidgetKit + AppIntents), supports circular/corner/rectangular families

Views use `@StateObject` for `Score` and `@State` for game-level scores (set tracking). Game win is determined at 50 points (index 4 in scoreArr), set win at 6 games.

## Conventions

- Korean commit messages with emoji prefixes (🎨 UI, 🐛 fix, 📝 docs, 🚨 lint)
- No external dependencies — SwiftUI, WidgetKit, AppIntents only
- Colors are inline (green=ME, orange=OPP) — no centralized theme system
- SwiftLint: line length 150/200, disabled `trailing_comma`, `todo`, `opening_brace`
- SwiftFormat: 4-space indent, max width 150, alphabetical imports
