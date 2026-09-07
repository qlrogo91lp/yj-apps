# CLAUDE.md — GolfCounter

**공통 규약(작업 방식·Git Workflow·빌드 개요·YJKit 사용법)은 저장소 루트 `CLAUDE.md` 를 먼저 본다.**
이 문서는 GolfCounter 앱 고유 내용만 다룬다.

## Project overview

GolfCounter — 워치 메인 입력, iOS는 기록·통계 전용인 골프 스트로크 카운터.
설계는 `docs/specs/shared/2026/2026-07-31-golfcounter-rebuild-design.md` 참조 (v1 리빌드 진행 중).
타깃: `GolfCounter`(iOS 17+) / `GolfCounter Watch App`(watchOS 10+) / `ComplicationAppExtension`(watch 위젯).
의존성: 모노레포 로컬 패키지 `Packages/YJKit` — WorkoutCore / ConnectivityCore / PersistenceCore / WorkoutUI. 그 외 없음.
스킴 이름은 `GolfComplicationExtension` 이지만 타깃 이름은 `ComplicationAppExtension` 이다 (출시 산출물명 유지 목적).

## Commands

루트에서 실행한다. 공통 명령·시뮬레이터 지정 규칙은 루트 `CLAUDE.md` 참조.

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')

# iOS
xcodebuild -workspace YJApps.xcworkspace -scheme "GolfCounter" \
  -destination "id=$IOS" build   # 또는 test

# watch
xcodebuild -workspace YJApps.xcworkspace -scheme "GolfCounter Watch App" \
  -destination "id=$WATCH" build   # 또는 test

# complication
xcodebuild -workspace YJApps.xcworkspace -scheme "GolfComplicationExtension" \
  -destination "id=$WATCH" build
```

린트는 이 앱 폴더에서 `swiftlint` / `swiftformat --lint .` 를 직접 돌리거나,
루트에서 `make lint` / `make format` 으로 두 앱을 함께 검사한다.

## Architecture & Conventions

- `Shared/`(Models·Persistence·Services, 양 타깃 공유) / `iOSApp/`·`WatchApp/`(Features + Components) / `ComplicationApp/`
- pbxproj는 Xcode 16 `PBXFileSystemSynchronizedRootGroup` — 파일 생성/삭제는 파일시스템 조작만으로 빌드에 반영된다
- 테스트: Swift Testing, `iosTests/`·`watchosTests/`에서 소스 구조 미러링, ViewModel 우선, View는 테스트 안 함
- 데이터: `GolfRound`(SwiftData, CloudKit 규칙: 기본값/optional, 병렬 배열) / `RoundSnapshot`(진행 중 상태, App Group `group.com.yj.GolfCounter`)
- 워치→iOS 단방향 전송(`.reliable`), iOS만 SwiftData 저장

폴더·컴포넌트 계층·Import·네이밍 컨벤션은 루트 `CLAUDE.md` 의 **앱 코드 컨벤션**을 따른다. 이 앱의 예외는 없다.

## Docs

커밋 시점 등 공통 규약은 루트 `CLAUDE.md` 를 따른다. 이 앱의 배치 규칙만 여기 적는다.

- `docs/specs/` — 설계
- `docs/plans/` — 구현 계획
- 폴더 구조·파일명 규칙은 루트 `CLAUDE.md` 의 "Docs 공통 규약" 을 따른다. **플랫폼은 파일명
  prefix가 아니라 `ios/`·`watch/`·`shared/` 폴더가 구분한다** (예전 `common-` prefix = `shared/`)
