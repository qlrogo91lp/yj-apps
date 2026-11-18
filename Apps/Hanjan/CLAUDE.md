# CLAUDE.md — 한잔 (Hanjan)

**공통 규약은 저장소 루트 `CLAUDE.md` 를 먼저 본다.** 이 문서는 한잔 고유 내용만 다룬다.

술자리에서 마신 잔을 워치·폰 어디서든 한 번 눌러 세고 한도 대비 진행을 보여 주는 앱. Linear YJ-42.

- 무엇을 만들지 — `docs/specs/shared/2026/2026-11-15-hanjan-design.md`
- 어떻게·어떤 순서로 — `docs/plans/shared/2026/2026-11-15-hanjan-implementation.md`

| 타깃 (= 공유 스킴) | 번들 ID | 폴더 | YJKit |
|---|---|---|---|
| `Hanjan` | `com.yj.Hanjan` | `iOSApp` `Shared` `Common` | ConnectivityCore, PersistenceCore |
| `Hanjan Watch App` | `com.yj.Hanjan.watchkitapp` | `WatchApp` `Shared` `Common` | ConnectivityCore |
| `HanjanComplicationExtension` | `com.yj.Hanjan.watchkitapp.ComplicationApp` | `ComplicationApp` `Common` | — |
| `HanjanLiveActivityExtension` | `com.yj.Hanjan.HanjanLiveActivity` | `LiveActivity` `Common` | — |
| `HanjanTests` | `com.yj.HanjanTests` | `iosTests` | — |
| `HanjanWatchTests` | `com.yj.HanjanWatchTests` | `watchosTests` | — |

최소 버전 iOS 17.0 / watchOS 10.0. `WorkoutCore` · HealthKit 을 쓰지 않는다.

- **프로젝트 파일은 `Hanjan.xcodeproj/project.xcproj`** (Xcode 27 새 형식, JSON). 다른 앱의 `project.pbxproj` 와 다르다
- `Common/` 은 확장 타깃도 붙는다 — Foundation · SwiftUI 만 쓴다. `ConnectivityCore` 에 기대는 코드는 `Shared/` 에 둔다 (확장은 YJKit 을 링크하지 않는다)
- ⚠️ App Group `group.com.yj.Hanjan` 은 워치 앱과 컴플리케이션 두 타깃의 엔타이틀먼트에 있다. 빠져도 빌드는 통과하고 실행에서만 조용히 빈 값이 된다
- iOS 엔타이틀먼트: iCloud(CloudKit, `iCloud.com.yj.Hanjan`) · `aps-environment`
- 테스트는 Swift Testing. `iosTests/` 는 `iOSApp/` · `Shared/` 를, `watchosTests/` 는 `WatchApp/` 을 따라간다

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme HanjanTests -destination "id=$IOS" test
xcodebuild -workspace YJApps.xcworkspace -scheme HanjanWatchTests -destination "id=$WATCH" test
```
