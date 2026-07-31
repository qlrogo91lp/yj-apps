# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

GolfCounter — 워치 메인 입력, iOS는 기록·통계 전용인 골프 스트로크 카운터.
설계는 `docs/superpowers/specs/2026-07-31-golfcounter-rebuild-design.md` 참조 (v1 리빌드 진행 중).
타깃: `GolfCounter`(iOS 17+) / `GolfCounter Watch App`(watchOS 10+) / `ComplicationAppExtension`(watch 위젯).
의존성: `../ralli-kit` 로컬 SPM (WorkoutCore / ConnectivityCore / PersistenceCore). 그 외 없음.

## Commands

```bash
make lint      # swiftlint
make format    # swiftformat --lint (검사만)
make fix       # 자동 수정

# iOS 빌드/테스트
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build   # 또는 test

# watch 빌드/테스트 (기기명은 xcrun simctl list devices available로 확인)
xcodebuild -project GolfCounter.xcodeproj -scheme "GolfCounter Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build   # 또는 test
```

## Architecture & Conventions

폴더 구조·계층화 컴포넌트·MVVM·테스트 규칙은 tennis_counter(`../tennis_counter/CLAUDE.md`) 컨벤션을 그대로 따른다. 요약:

- `Shared/`(Models·Persistence·Services, 양 타깃 공유) / `iOSApp/`·`WatchApp/`(Features + Components) / `ComplicationApp/`
- pbxproj는 Xcode 16 `PBXFileSystemSynchronizedRootGroup` — 파일 생성/삭제는 파일시스템 조작만으로 빌드에 반영된다
- 테스트: Swift Testing, `iosTests/`·`watchosTests/`에서 소스 구조 미러링, ViewModel 우선, View는 테스트 안 함
- 데이터: `GolfRound`(SwiftData, CloudKit 규칙: 기본값/optional, 병렬 배열) / `RoundSnapshot`(진행 중 상태, App Group `group.com.yj.GolfCounter`)
- 워치→iOS 단방향 전송(`.reliable`), iOS만 SwiftData 저장

## Git Workflow

- `main` 직접 push 금지 — 브랜치 + PR, 머지는 항상 일반 merge commit (`gh pr merge <n> --merge --delete-branch`)
- 커밋 메시지는 gitmoji prefix: ✨ feat / 🐛 fix / ♻️ refactor / 🎨 style / 📝 docs / ✅ test / 🔧 chore / 🔥 remove / ⏪ revert

## Docs

`docs/superpowers/specs/`(설계)·`plans/`(구현 계획, 파일명에 common-/watch-/ios- prefix). 사용자 검토 전에는 커밋하지 않는다.
