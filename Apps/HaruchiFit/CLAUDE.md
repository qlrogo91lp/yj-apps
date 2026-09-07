# CLAUDE.md — HaruchiFit

**공통 규약(작업 방식·Git Workflow·빌드 개요·YJKit 사용법)은 저장소 루트 `CLAUDE.md` 를 먼저 본다.**
이 문서는 하루치 핏 앱 고유 내용만 다룬다.

## Project overview

하루치 핏(Haruchi Fit) — 워치에서 근력/유산소 **세그먼트**를 기록하고, iOS는 잔디·기록·통계를
보여주는 운동 기록 앱. 폰을 한 번도 안 열어도 기록이 완결되는 것이 해피패스다.

- 무엇을 만들지 — `docs/superpowers/specs/2026-09-02-haruchi-fit-product-spec.md`
- 어떻게 만들지 — `docs/superpowers/specs/2026-09-02-haruchi-fit-architecture.md` (결정 사항 D-M1~D-M8은 6절)
- 지금 어디까지 왔나 — `docs/superpowers/plans/2026-09-07-haruchi-fit-roadmap.md` (**살아있는 문서**)

**구현 초기 단계다.** 워치 세션 기반과 세그먼트 저장까지 되어 있고, iOS는 화면이 없다.

| 타깃 | 번들 ID | 최소 버전 |
|---|---|---|
| `HaruchiFit` | `com.yj.HaruchiFit` | iOS 17 |
| `HaruchiFit Watch App` | `com.yj.HaruchiFit.watchkitapp` | watchOS 10 |
| `HaruchiComplicationExtension` | `com.yj.HaruchiFit.watchkitapp.ComplicationApp` | watchOS 10 |
| `HaruchiFitWatchTests` | `com.yj.HaruchiFitWatchTests` | — |

프로덕트 링크 (`Packages/YJKit`, pbxproj 기준):

| 타깃 | 링크된 프로덕트 |
|---|---|
| `HaruchiFit` | ConnectivityCore, PersistenceCore, WorkoutCore, WorkoutUI, WorkoutShareUI |
| `HaruchiFit Watch App` | ConnectivityCore, WorkoutCore, WorkoutUI |
| `HaruchiComplicationExtension` | 없음 — 로컬 스냅샷만 읽는다 |

**Golf·Tennis 와 다른 점: 워치 테스트가 전용 스킴(`HaruchiFitWatchTests`)이다.**
그쪽 두 앱은 앱 스킴에 `-only-testing` 을 걸지만 여기는 그럴 필요가 없다.

## Commands

루트에서 실행한다. 공통 명령·시뮬레이터 지정 규칙은 루트 `CLAUDE.md` 참조.

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')

# iOS — 아직 테스트 타깃이 없다. 빌드만.
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFit" \
  -destination "id=$IOS" build

# watch 테스트 — 호스트인 워치 앱까지 함께 빌드된다
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" \
  -destination "id=$WATCH" test

# complication
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiComplicationExtension" \
  -destination "id=$WATCH" build
```

린트는 이 앱 폴더에서 `swiftlint` / `swiftformat --lint .` 를 돌리거나 루트에서 `make lint` / `make format`.

## Architecture & Conventions

```
iOSApp/           iOS 앱
WatchApp/         watchOS 앱
ComplicationApp/  컴플리케이션 익스텐션
Shared/           워치 앱 ↔ 컴플리케이션 공유 (스냅샷·표시 상태)
watchosTests/     Swift Testing
```

- **`Shared/` 가 있는 이유** — 위젯 타깃에는 테스트 타깃을 붙일 수 없다. 컴플리케이션의 표시
  로직을 `Shared/` 에 두고 워치 테스트 타깃에서 검증한다 (GolfCounter 와 같은 구조).
- pbxproj는 Xcode 16 `PBXFileSystemSynchronizedRootGroup` — 파일 생성/삭제는 파일시스템 조작만으로 반영된다.
- 폴더 계층·컴포넌트 배치·네이밍(`Features/` · `Components/` 3계층 · 한 파일 한 타입)은
  **Golf·Tennis 와 동일한 규칙**을 따른다. 상세 표는 `Apps/GolfCounter/CLAUDE.md` 를 본다.
- 테스트: Swift Testing, ViewModel 우선, View는 테스트하지 않는다.

### 데이터 — HealthKit 과 SwiftData 의 역할 분리

| 데이터 | 원본 |
|---|---|
| 워크아웃 시각·시간·칼로리·심박 | **HealthKit** (SwiftData는 캐시) |
| 세그먼트 · 부위 태그 · 메모 | **SwiftData** — HealthKit에 자리가 없다 |
| 잔디 일별 집계 | SwiftData 파생 |

- `HKWorkoutActivity` 의 **이종 구간 전환은 실기기에서 불가능함이 확인됐다** (2026-09-03).
  세그먼트는 앱이 직접 소유한다. 아키텍처 문서 2절이 근거다.
- 워크아웃 세션 타입은 **근력으로 고정**한다 (D-M8).
- 매칭 키는 `healthKitUUID`. CloudKit 제약으로 `.unique` 를 걸 수 없으므로
  **중복 방지는 앱 코드 책임**이다. HealthKit 메타데이터에 부위를 넣지 않는다.

### 폰↔워치

루트 `CLAUDE.md` 의 **워크아웃 동작 계약 3조**를 그대로 지킨다. 추가로:

- `WorkoutMetricsMessage` 는 반드시 `.realtimeOnly` — 앵커 보간이 "방금 보냄" 전제 위에 있다
- `ConnectivityService` 는 프로세스당 하나. `onReceive` 등록은 생성한 main-queue turn 안에서 끝낸다
- 세그먼트 전환용 실시간 메시지는 **두지 않는다.** 저장 시점에 결과와 함께 한 번만 보낸다

## Docs

커밋 시점 등 공통 규약은 루트 `CLAUDE.md` 를 따른다. 이 앱의 배치 규칙만 여기 적는다.

- `docs/superpowers/specs/` — 확정 설계
- `docs/superpowers/plans/` — 구현 계획
- **상세 플랜은 각 작업 착수 직전에 쓴다.** 미리 쓴 플랜은 앞의 두어 개만 살아남는다는 것을
  두 번 겪었다 (로드맵 문서 서두에 근거). 로드맵은 작업이 끝날 때마다 갱신한다.
- 모노레포 공통 문서(CI·코드 스타일·Xcode 타깃 규약)는 **루트 `docs/superpowers/`** 에 있다
