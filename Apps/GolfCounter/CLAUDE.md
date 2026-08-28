# CLAUDE.md — GolfCounter

**공통 규약(작업 방식·Git Workflow·빌드 개요·YJKit 사용법)은 저장소 루트 `CLAUDE.md` 를 먼저 본다.**
이 문서는 GolfCounter 앱 고유 내용만 다룬다.

## Project overview

GolfCounter — 워치 메인 입력, iOS는 기록·통계 전용인 골프 스트로크 카운터.
설계는 `docs/superpowers/specs/2026-07-31-golfcounter-rebuild-design.md` 참조 (v1 리빌드 진행 중).
타깃: `GolfCounter`(iOS 17+) / `GolfCounter Watch App`(watchOS 10+) / `ComplicationAppExtension`(watch 위젯).
의존성: 모노레포 로컬 패키지 `Packages/YJKit` — WorkoutCore / ConnectivityCore / PersistenceCore / WorkoutUI. 그 외 없음.
스킴 이름은 `GolfComplicationExtension` 이지만 타깃 이름은 `ComplicationAppExtension` 이다 (출시 산출물명 유지 목적).

## Commands

루트에서 실행한다. 공통 명령·워치 UDID 주의사항은 루트 `CLAUDE.md` 참조.

```bash
# iOS
xcodebuild -workspace YJApps.xcworkspace -scheme "GolfCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build   # 또는 test

# watch (UDID는 xcrun simctl list devices available 로 확인)
xcodebuild -workspace YJApps.xcworkspace -scheme "GolfCounter Watch App" \
  -destination "id=<워치 시뮬레이터 UDID>" build   # 또는 test

# complication
xcodebuild -workspace YJApps.xcworkspace -scheme "GolfComplicationExtension" \
  -destination "id=<워치 시뮬레이터 UDID>" build
```

린트는 이 앱 폴더에서 `swiftlint` / `swiftformat --lint .` 를 직접 돌리거나,
루트에서 `make lint` / `make format` 으로 두 앱을 함께 검사한다.

## Architecture & Conventions

- `Shared/`(Models·Persistence·Services, 양 타깃 공유) / `iOSApp/`·`WatchApp/`(Features + Components) / `ComplicationApp/`
- pbxproj는 Xcode 16 `PBXFileSystemSynchronizedRootGroup` — 파일 생성/삭제는 파일시스템 조작만으로 빌드에 반영된다
- 테스트: Swift Testing, `iosTests/`·`watchosTests/`에서 소스 구조 미러링, ViewModel 우선, View는 테스트 안 함
- 데이터: `GolfRound`(SwiftData, CloudKit 규칙: 기본값/optional, 병렬 배열) / `RoundSnapshot`(진행 중 상태, App Group `group.com.yj.GolfCounter`)
- 워치→iOS 단방향 전송(`.reliable`), iOS만 SwiftData 저장

아래 폴더 계층·컴포넌트 배치·네이밍 규칙은 tennis_counter(`../tennis_counter/CLAUDE.md`)의 컨벤션을 그대로 미러링한 것이다 (원본 출처이지 유일한 근거는 아님 — 이 파일이 최종 참조).

### 폴더별 배치 기준

| 폴더 | 무엇을 두는가 | 두지 않는 것 |
|------|-------------|-------------|
| `Features/` | 탭 또는 도메인 단위 기능. View + ViewModel 한 쌍이 기본. 하위에 화면 단위 서브폴더 허용. | 여러 Feature에서 공유되는 UI → `Components/` (앱 전역) |
| `Features/X/Components/` | 해당 Feature 전용 재사용 UI 컴포넌트. 다른 Feature에서 import하면 안 됨. | 비즈니스 로직, ViewModel |
| `Features/X/ScreenName/Components/` | 특정 View 전용 순수 컴포넌트. 같은 폴더의 View에서만 import. | 다른 View에서 공유 컴포넌트 |
| `Shared/Models/` | 플랫폼 독립 데이터 모델. SwiftData `@Model` 클래스, 순수 struct/enum. iOS·Watch 양쪽에서 쓰는 것만. | UI 코드, 프레임워크 의존 코드 |
| `Shared/Services/` | 시스템 프레임워크(HealthKit, WatchConnectivity, CloudKit 등) 래퍼. 호출부가 프레임워크 API를 직접 참조하지 않도록 추상화. | View, ViewModel, 데이터 모델 |

### 계층화된 컴포넌트 구조

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

### 파일 네이밍

- View suffix: 독립적인 화면/페이지만 (e.g., `ModeView.swift`, `SingleGameView.swift`)
- `Components/` 안의 순수 컴포넌트: suffix 없음 (e.g., `UndoButton.swift`)
- 한 파일 = 한 타입: 같은 파일에 여러 View/ViewModel 정의 금지 (단, private helper component는 예외)

## Docs

커밋 시점 등 공통 규약은 루트 `CLAUDE.md` 를 따른다. 이 앱의 배치 규칙만 여기 적는다.

- `docs/superpowers/specs/` — 설계
- `docs/superpowers/plans/` — 구현 계획. 파일명에 `common-` / `watch-` / `ios-` prefix를 붙인다
