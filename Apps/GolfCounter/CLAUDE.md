# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

GolfCounter is a SwiftUI golf stroke counter shipped as two apps from a single Xcode project: an iOS app (`GolfCounter`, bundle `com.yj.GolfCounter`, iOS 16.4+) and a watchOS app (`GolfCounter Watch App`, bundle `com.yj.GolfCounter.watchkitapp`, watchOS 9.0+) that the iOS target embeds via its "Embed Watch Content" phase. No package manager, no external dependencies — pure SwiftUI + Foundation, Swift 5.0.

## Commands

Schemes are `GolfCounter` and `GolfCounter Watch App` (`xcodebuild -list -project GolfCounter.xcodeproj`).

Lint and format:

```bash
make lint      # swiftlint
make format    # swiftformat --lint . (검사만, 파일 미변경)
make fix       # swiftformat . + swiftlint --fix (자동 수정)
```

Build (building the iOS scheme also builds the embedded watch app):

```bash
xcodebuild -project GolfCounter.xcodeproj -scheme GolfCounter -destination 'generic/platform=iOS' build
```

Note: this machine currently has the iOS/watchOS **SDKs** installed but no simulator **runtimes** and no iOS device platform support, so `xcodebuild` cannot resolve any destination. Until runtimes are installed, verify compilation by typechecking against the SDK directly:

```bash
xcrun swiftc -typecheck -sdk $(xcrun --sdk iphonesimulator26.5 --show-sdk-path) -target arm64-apple-ios16.4-simulator -swift-version 5 GolfCounter/**/*.swift
```

Run tests (pick a concrete destination from `xcrun simctl list devices available` — see the runtime caveat above):

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
- The `SingleGameView` file is named `Views/Single/SinglegGameView.swift` on iOS (typo) and `Views/Single/SingleGameView.swift` on watch. `HoleType` (`par3`/`par4`/`par5`, raw values `"3"/"4"/"5"`) is declared inside that file, so it exists once per target.
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

- Par is a `String` throughout and is force-unwrapped as `Int(scoreDetail.maxHole)!` / `Int(item)!` at every use site. Keep `maxHole` constrained to `"3"`/`"4"`/`"5"`. SwiftLint's `force_unwrapping` rule is deliberately enabled and reports these 8 sites as warnings — they are the marker for the eventual `String` → `Int`/`HoleType` model change, not noise to silence.
- Score is clamped in the button actions themselves: increment stops at `par * 2`, decrement stops at `0`.
- "Hole Type" / "Type" buttons cycle par 3 → 4 → 5 → 3 by mutating `maxHole` directly.
- `ScoreView` colors the result relative to par: green when at/under (and for the unplayed `score == 0` case), red with a `+` prefix when over.

## Lint & Format

SwiftLint and SwiftFormat are wired up via `Makefile`; run `make fix` before committing. The iOS target also has a `SwiftLint` shell-script build phase (runs before `Sources`, warns instead of failing if SwiftLint is missing), so violations surface in Xcode.

- **`.swiftlint.yml`** — `included` limits linting to `GolfCounter` and `GolfCounter Watch App` (test targets are not linted). line_length 150/200; `trailing_comma`, `todo`, `opening_brace` disabled; `identifier_name` min length 1 for short SwiftUI names; `type_name.excluded` carries `GolfCounter_Watch_AppApp`. Opt-in rules: `empty_count`, `closure_spacing`, `first_where`, `modifier_order`, `force_unwrapping`.
- **`.swiftformat`** — `--swiftversion 5.0` (matches `SWIFT_VERSION`), 4-space indent, maxwidth 150, `--self remove`, `--header ignore`, `--importgrouping alpha`; `acronyms`, `blankLinesAtStartOfScope`, `blankLinesAtEndOfScope` disabled.

Current state: `make lint` and `make format` both pass; the only outstanding violations are the 8 intentional `force_unwrapping` warnings noted above.

## Folder & File Conventions

These are the **target** conventions, aligned with the sibling tennis-counter project. The codebase does not conform yet (see "Duplicated sources" above) — apply them incrementally as files are touched rather than as a separate refactor.

### Layering

Components are promoted upward by how widely they are reused; each layer may only be imported by layers above it.

```
앱 루트 Components/       ← 두 Feature 이상이 공유 (가장 재사용 가능)
    ↑
Features/X/Components/    ← Feature 내 여러 View가 공유
    ↑
ScreenName/Components/    ← 특정 View 전용 (가장 낮은 계층)
```

| 폴더 | 두는 것 | 두지 않는 것 |
|------|--------|------------|
| `Shared/` | iOS·watch 양쪽이 쓰는 플랫폼 독립 로직(Model, 순수 struct/enum, Service) | UI 코드, 한쪽 타깃 전용 코드 |
| `Features/X/` | 도메인/화면 단위 기능. View + ViewModel 한 쌍이 기본 | 여러 Feature가 공유하는 UI → 루트 `Components/` |
| `Features/X/Components/` | 해당 Feature 전용 재사용 UI | 비즈니스 로직, ViewModel |
| `Features/X/ScreenName/Components/` | 특정 View 전용 순수 컴포넌트 | 다른 View와 공유하는 컴포넌트 |

Import 규칙 (순환 의존성 금지): `ScreenName/Components/` → 상위 View/ViewModel import 금지 · `Features/X/Components/` → 다른 Feature import 금지 · Feature → `Shared/`만 import 가능 · ViewModel → UI 프레임워크 import 금지.

### File naming

- `View` suffix는 독립적인 화면/페이지에만 붙인다 (`ScoreSetupView.swift`, `SingleGameView.swift`).
- `Components/` 안의 순수 컴포넌트는 suffix 없음 (`UndoButton.swift` 식).
- 한 파일 = 한 타입. 같은 파일에 여러 View/ViewModel 정의 금지 (파일 내 `private` 헬퍼 컴포넌트는 예외).
- Enum 케이스는 lowerCamelCase (`HoleType.par3`) — SwiftLint `identifier_name`이 error로 잡는다.

### Adding files — legacy pbxproj caveat

This project uses **legacy `PBXGroup`** file references (`objectVersion = 56`), **not** Xcode 16's `PBXFileSystemSynchronizedRootGroup`. Unlike tennis-counter, creating a file on disk does **not** add it to the build:

- New `.swift` files must be added to the target in Xcode, or `project.pbxproj` must be edited to add both a `PBXBuildFile`/`PBXFileReference` pair and a `PBXGroup` entry.
- A file needed by both apps must be added to **both** targets (or duplicated, per the current structure).

## Git Workflow

- `main`은 직접 push 금지 — 항상 브랜치를 만들고 PR을 통해 병합한다.
- PR 머지 시 **squash 금지, 항상 일반 merge commit**을 사용한다 (저장소 설정에서 squash/rebase merge 버튼 자체를 비활성화해뒀다).

  ```bash
  gh pr merge <number> --merge --delete-branch
  ```

- 커밋 메시지는 **gitmoji**를 맨 앞에 붙인다 (`이모지 타입: 설명` 형태, Conventional Commits 타입과 병행):

  | 이모지 | 타입 | 용도 |
  |---|---|---|
  | ✨ | feat | 새 기능 |
  | 🐛 | fix | 버그 수정 |
  | ♻️ | refactor | 동작 변경 없는 구조 개선 |
  | 🎨 | style | 포맷팅/린트 자동 수정 등 동작 무관 변경 |
  | 📝 | docs | 문서 |
  | ✅ | test | 테스트 추가/수정 |
  | 🔧 | chore | 설정, 빌드, 잡무 |
  | 🔥 | remove | 코드/파일 삭제 |
  | ⏪ | revert | 되돌리기 |

## Repo state

- `.gitignore` covers macOS, Xcode user state (`xcuserdata/`), build products, and SPM/CocoaPods/Carthage/fastlane. `xcuserdata/` has been removed from the index, so local Xcode UI activity no longer shows up as diffs.
- The top-level `Widget/`, `GolfCounterWidget/`, `GolfCounter Widget/`, `Complications/`, `GolfCounterComplication/`, `GolfCounter Complication/`, and `GolfCounter Watch Widget/` directories contain only leftover `Assets.xcassets` and belong to no target. There is no widget or complication implementation.
- Signing uses `DEVELOPMENT_TEAM = P2TU28W32L`; iOS `MARKETING_VERSION` is 2.0, watch 1.0.
