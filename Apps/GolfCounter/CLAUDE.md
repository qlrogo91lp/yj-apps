# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

GolfCounter is a SwiftUI golf stroke counter shipped as two apps from a single Xcode project: an iOS app (`GolfCounter`, bundle `com.yj.GolfCounter`, iOS 16.4+) and a watchOS app (`GolfCounter Watch App`, bundle `com.yj.GolfCounter.watchkitapp`, watchOS 9.0+) that the iOS target embeds via its "Embed Watch Content" phase. No package manager, no external dependencies — pure SwiftUI + Foundation, Swift 5.0.

## Commands

Schemes are `GolfCounter` and `GolfCounter Watch App` (`xcodebuild -list -project GolfCounter.xcodeproj`).

Build (no simulator runtime needed — building the iOS scheme also builds the embedded watch app):

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme GolfCounter -destination 'generic/platform=iOS' build
```

Run tests (pick a concrete destination from `xcrun simctl list devices available` — the runtimes on this machine are currently all listed unavailable, so simulator runtimes must be installed first):

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme GolfCounter -destination 'platform=iOS Simulator,name=iPhone 15' test
```

Run a single test:

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme GolfCounter -destination 'platform=iOS Simulator,name=iPhone 15' test -only-testing:GolfCounterTests/GolfCounterTests/testExample
```

All six test files (`GolfCounterTests`, `GolfCounterUITests`, and the two watch equivalents) are still unmodified Xcode templates — there is no real test coverage to preserve.

## Architecture

### Duplicated sources, not shared

`GolfCounter/` and `GolfCounter Watch App/` each contain their own full copy of every `Model/` and `Views/` file, compiled into their own target. There is no shared framework or shared file group. **Any behavior change must be applied to both copies**, or the two apps silently diverge (they already have).

Divergences to be aware of when mirroring:

- iOS views wrap their content in `ZStack { Color.black.edgesIgnoringSafeArea(.all) … }` and use large `.font(.system(size: 30–40))`; watch views drop the ZStack, use ~20–30pt fonts, and add `.buttonStyle(PlainButtonStyle())` to the circular +/− buttons so watchOS doesn't draw its own button chrome.
- The `SingleGameView` file is named `Views/Single/SinglegGameView.swift` on iOS (typo) and `Views/Single/SingleGameView.swift` on watch. `HoleType` (Par3/4/5, raw values `"3"/"4"/"5"`) is declared inside that file, so it exists once per target.
- Watch-only `Model/ScoreList.swift` is an empty `ObservableObject` with its intended `[ScoreDetail]` array entirely commented out — an unfinished refactor, not live code.

### Two independent flows

`ContentView` is just a `NavigationStack` with two links:

- **Single Game** — `SingleGameView` (wheel `Picker` over `HoleType`) → `SingleGameCounterView(maxHole:)`, a throwaway counter for one hole backed by the `Score` struct (`@State var score = Score()`). Nothing is recorded.
- **Score Board** — `ScoreListView` → per-hole `ScoreView` row → `ScoreSetupView` for editing.

### State model

`ScoreDetail` (class, `ObservableObject`, `Identifiable`) is the only real state: `id` (hole number), `maxHole` (par, stored as a `String`), `score`. `ScoreListView` declares **18 separate `@StateObject` properties** (`hole1`…`hole18`) and 18 hand-written `NavigationLink` rows, then computes `total` by summing all 18 inline inside `body`. Adding or reordering holes means editing all three of those hand-rolled lists (and in both targets).

Child views receive an existing `ScoreDetail` through `@StateObject var scoreDetail:` rather than `@ObservedObject`. This is the established pattern across `ScoreView` and `ScoreSetupView`; be aware it means SwiftUI takes ownership on first render, so replacing the passed-in object will not refresh the child.

There is **no persistence layer** — no UserDefaults, SwiftData, or WatchConnectivity. All scores are lost on relaunch, and iOS and watch state are completely separate.

### Conventions and hazards

- Par is a `String` throughout and is force-unwrapped as `Int(scoreDetail.maxHole)!` / `Int(item)!` at every use site. Keep `maxHole` constrained to `"3"`/`"4"`/`"5"`.
- Score is clamped in the button actions themselves: increment stops at `par * 2`, decrement stops at `0`.
- "Hole Type" / "Type" buttons cycle par 3 → 4 → 5 → 3 by mutating `maxHole` directly.
- `ScoreView` colors the result relative to par: green when at/under (and for the unplayed `score == 0` case), red with a `+` prefix when over.

## Repo state

- There is no `.gitignore`. `.DS_Store` files are present but untracked; `GolfCounter.xcodeproj/xcuserdata/` (breakpoints, scheme management) **is** tracked, so local Xcode UI activity shows up as diffs — don't commit those incidentally.
- The top-level `Widget/`, `GolfCounterWidget/`, `GolfCounter Widget/`, `Complications/`, `GolfCounterComplication/`, `GolfCounter Complication/`, and `GolfCounter Watch Widget/` directories contain only leftover `Assets.xcassets` and belong to no target. There is no widget or complication implementation.
- Signing uses `DEVELOPMENT_TEAM = P2TU28W32L`; iOS `MARKETING_VERSION` is 2.0, watch 1.0.
