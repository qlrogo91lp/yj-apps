# CLAUDE.md — HaruchiFit

**공통 규약(작업 방식·Git Workflow·빌드 개요·YJKit 사용법)은 저장소 루트 `CLAUDE.md` 를 먼저 본다.**
이 문서는 하루치 핏 앱 고유 내용만 다룬다.

## Project overview

하루치 핏(Haruchi Fit) — 워치에서 근력/유산소 **세그먼트**를 기록하고, iOS는 잔디·기록·통계를
보여주는 운동 기록 앱. 폰을 한 번도 안 열어도 기록이 완결되는 것이 해피패스다.

- 무엇을 만들지 — `docs/specs/shared/2026/2026-09-02-haruchi-fit-product-spec.md`
- 어떻게 만들지 — `docs/specs/shared/2026/2026-09-02-haruchi-fit-architecture.md` (결정 사항 D-M1~D-M8은 6절)
- 무엇을 어떤 순서로 — `docs/specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md` (**살아있는 문서**. 진행 상태도 여기가 단일 출처)

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
WatchApp/
  WatchApp.swift                    진입점
  BrandColor.swift                  색 토큰 (타깃마다 따로 둔다 — 골프·테니스도 그렇다)
  Features/Workout/                 단계별 화면 + 뷰모델
    WorkoutRootView.swift           phase 분기만
    WorkoutViewModel.swift · SessionPhase.swift
    Start/ · Session/ · Summary/    각 단계의 화면
    Summary/Components/             그 화면 전용 순수 컴포넌트
  Services/                         시스템 프레임워크 래퍼와 그 프로토콜
iOSApp/
  iOSApp.swift · ContentView.swift  ContentView 는 저장 확인용 임시 화면이다
  Services/
ComplicationApp/                    컴플리케이션 익스텐션
Shared/                             워치 앱 ↔ iOS 앱 공유
  Persistence/                      SwiftData @Model
  Services/                         전송 메시지
watchosTests/
  Workout/ · Support/               테스트는 대상 폴더를 따라간다
```

- **`Shared/` 에 UI 를 두지 않는다.** 루트 `CLAUDE.md` 규약이고, 골프·테니스의 `Shared/` 에도
  SwiftUI 파일이 하나도 없다. 워치·iOS 가 같은 뷰를 써야 하면 `Packages/YJKit` 의 `WorkoutUI`
  프로덕트로 올리거나(거기 `Shared/`·`Watch/`·`iOS/` 로 갈라 둔 자리가 있다) 복제한다.
- ⚠️ **`Shared/` 는 컴플리케이션 타깃에 들어 있지 않다** (워치 앱 + iOS 앱만). 골프는 들어 있어
  `Shared/Models/ComplicationState.swift` 로 표시 로직을 공유하고 워치 테스트로 검증하는데,
  하루치는 그 구조가 아직 없다. **WC 작업 전에 Xcode 에서 컴플리케이션 타깃에 `Shared` 를
  추가해야 한다** — 안 그러면 스냅샷 스토어를 `Shared/` 에 둔 순간 컴파일이 안 된다.
- pbxproj는 Xcode 16 `PBXFileSystemSynchronizedRootGroup` — 파일 생성/삭제는 파일시스템 조작만으로 반영된다.
- 폴더·컴포넌트 계층·Import·네이밍 컨벤션은 루트 `CLAUDE.md` 의 **앱 코드 컨벤션**을 따른다
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

- `docs/specs/` — 확정 설계. **로드맵도 여기 있다** — 15개 항목의 순서·의존 관계를 확정할 뿐
  파일 단위 설계를 담지 않으므로 플랜이 아니다. 작업이 끝날 때마다 갱신한다
- `docs/plans/` — 구현 계획. 파일 단위(`Task N — Files: Create/Modify`)로 쓴다
- **상세 플랜은 각 작업 착수 직전에 쓴다.** 미리 쓴 플랜은 앞의 두어 개만 살아남는다는 것을
  두 번 겪었다 (로드맵 문서 서두에 근거).
- 모노레포 공통 문서(CI·코드 스타일·Xcode 타깃 규약)는 **루트 `docs/`** 에 있다
