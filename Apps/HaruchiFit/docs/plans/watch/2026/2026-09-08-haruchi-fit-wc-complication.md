# WC 컴플리케이션 — 구현 플랜

작성일: 2026-09-08
상태: **완료** — Task 0~4 (`a8401e2`~`9836055`). 실기기 검증만 남음
선행 문서: [제품 스펙](../../../specs/shared/2026/2026-09-02-haruchi-fit-product-spec.md) WC절 · [아키텍처](../../../specs/shared/2026/2026-09-02-haruchi-fit-architecture.md) D-M4
선행 작업: W0 (`7a2c73a`·`d60862e`) — 완료

**목표** — 진행 중인 세션 상태만 보여주는 컴플리케이션. 집계 값은 넣지 않는다 (D-M4).

**접근** — 골프의 `RoundSnapshot` / `RoundSnapshotStore` / `RoundSnapshotPublisher` 3종 구조를
그대로 옮긴다. 값이 다를 뿐 문제가 같다.

---

## 먼저 — 로드맵에 적혀 있던 선행 작업은 틀렸다

로드맵과 TODO 는 *"컴플리케이션 타깃에 `Shared` 폴더를 추가"* 라고 적어 두었다.
**그대로 하면 빌드가 깨진다.** 2026-09-08 에 실제로 붙여서 확인했다.

```
HaruchiComplicationExtension: clang: error: linker command failed with exit code 1
** BUILD FAILED **
```

`Shared/Services/WorkoutRecordMessage.swift` 가 `ConnectivityMessage` 를 채택해
**`ConnectivityCore` 에 의존**하는데, 컴플리케이션 타깃은 어떤 패키지 프로덕트도 링크하지 않는다.
골프의 `Shared/` 는 외부 의존이 없어 이 문제를 겪지 않았다 — 그래서 같은 문장이 하루치에선 안 통한다.

### 그래서 어디에 두나

| 안 | 내용 | 값 |
|---|---|---|
| **A (택함)** | 새 폴더 `Common/` 를 파고 **세 타깃 모두**에 붙인다 | 위젯이 의존 0인 파일만 컴파일한다. `Shared/` 는 지금 성질(iOS↔워치, ConnectivityCore 의존)을 유지한다 |
| B | `Shared` 를 붙이고 컴플리케이션에도 `ConnectivityCore` 를 링크한다 | 한 줄이면 되지만, **위젯이 절대 쓰지 않는 WatchConnectivity 래퍼를 끌고 들어간다.** 위젯 프로세스는 메모리 상한이 빡빡하다 |
| C | `WorkoutRecordMessage` 에서 `ConnectivityMessage` 의존을 걷어낸다 | 전송 계약을 손대는 일이라 파장이 WC 범위를 넘는다 |

A 를 택한다. **폴더가 타깃 부착의 단위**라(Xcode 16 동기화 그룹) `Shared/` 하위 폴더만 골라
붙일 수 없기 때문에, 의존이 다른 파일 묶음은 폴더가 갈려야 한다.

> **구현하며 드러난 것 — 두 타깃이 아니라 세 타깃이다.** `WorkoutSnapshot.mode` 가 `SegmentKind` 인데
> 그 enum 은 iOS 앱(`Segment`·`WorkoutRecordMessage`)도 쓴다. `Segment.swift` 에서 분리해 `Common/` 으로
> 옮기고 iOS 앱까지 셋에 붙였다. `SummaryFormat` 도 정지 중 경과시간 표기 때문에 함께 옮겼다.

### App Group 도 필요하다

워치 앱과 컴플리케이션은 **다른 프로세스**라 컨테이너를 공유하지 않는다. 골프는 App Group 으로
푼다 (`group.com.yj.GolfCounter`). 하루치엔 **App Group 이 아직 없고, 컴플리케이션용 entitlements
파일 자체가 없다.**

```
Apps/GolfCounter/ComplicationAppExtension.entitlements  → group.com.yj.GolfCounter
Apps/GolfCounter/GolfCounter Watch App.entitlements     → group.com.yj.GolfCounter + healthkit
Apps/HaruchiFit/HaruchiFit Watch App.entitlements       → healthkit 만
Apps/HaruchiFit/ (컴플리케이션용 entitlements 없음)
```

---

## Task 0 — Xcode 선행 작업 (**사용자**) — 완료

내가 할 수 없는 것들이다. 이게 끝나야 Task 1 이 컴파일된다.

- [x] **Step 1: 폴더를 만든다** — 내가 먼저 `Common/` 에 파일을 넣어 두면
      Xcode 가 폴더를 인식한다. 순서상 Task 1 의 첫 파일을 만든 뒤에 Step 2 로 간다

- [x] **Step 2: 세 타깃에 폴더를 붙인다**

  1. `YJApps.xcworkspace` 를 연다 (앱 `.xcodeproj` 를 따로 열지 않는다 — 루트 `CLAUDE.md`)
  2. 프로젝트 네비게이터에서 `HaruchiFit` › `Common` **폴더**를 선택 (안의 파일 말고)
  3. 오른쪽 File inspector (`⌥⌘1`) › **Target Membership**
  4. `HaruchiFit` · `HaruchiFit Watch App` · `HaruchiComplicationExtension` **셋 다** 체크
     (`HaruchiFitWatchTests` 는 체크하지 않는다)

  > **Add Files 의 `Create groups` 는 동기화 폴더를 만들지 않는다** — 파일을 하나씩 나열하는
  > 일반 그룹으로 들어가서, 이후 `Common/` 에 파일을 더해도 자동으로 안 잡힌다.
  > 프로젝트의 나머지 폴더와 같은 `PBXFileSystemSynchronizedRootGroup` 로 바꿔 넣었다 (`a8401e2`).

- [x] **Step 3: App Group 을 켠다** — 타깃 › Signing & Capabilities › `+ Capability` › App Groups

  | 타깃 | 그룹 |
  |---|---|
  | `HaruchiFit Watch App` | `group.com.yj.HaruchiFit` |
  | `HaruchiComplicationExtension` | `group.com.yj.HaruchiFit` |

  컴플리케이션 타깃은 entitlements 파일이 없어 Xcode 가 새로 만든다
  (`HaruchiComplicationExtension.entitlements`). 워치 앱 쪽은 기존 파일에 키가 더해진다.

  > 시뮬레이터 빌드는 이대로 통과한다. **실기기는 Apple Developer 의 App ID 에 App Group
  > capability 가 등록돼야 한다** — 자동 서명이면 Xcode 가 처리하지만, 실패하면 여기부터 본다.

- [x] **Step 4: 확인** — 아래를 내가 돌려서 검증한다

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiComplicationExtension" -destination "id=$WATCH" build
```

---

## 파일

| 파일 | 할 일 |
|---|---|
| `Common/SegmentKind.swift` | **신규(분리)** — `Shared/Persistence/Segment.swift` 에서 옮겼다 |
| `Common/SummaryFormat.swift` | **이동** — `WatchApp/.../Summary/` 에서 옮겼다 |
| `Common/WorkoutSnapshot.swift` | **신규** — 진행 중 세션 스냅샷. 의존 없음 |
| `Common/WorkoutSnapshotStore.swift` | **신규** — App Group `UserDefaults` 읽기/쓰기 |
| `Common/ComplicationState.swift` | **신규** — 표시값. 스냅샷 유무로 평상시/진행 중을 가른다 |
| `WatchApp/Services/WorkoutSnapshotPublisher.swift` | **신규** — 저장 + `reloadAllTimelines()` 를 한 동작으로. 프로토콜로 주입 |
| `WatchApp/Features/Workout/WorkoutViewModel.swift` | 수정 — start/switchMode/togglePause/end 에서 publish |
| `watchosTests/Support/WorkoutSnapshotPublisherSpy.swift` | **신규** |
| `watchosTests/Workout/WorkoutSnapshotTests.swift` | **신규** — 스토어·상태 |
| `watchosTests/Workout/WorkoutViewModelSnapshotTests.swift` | **신규** — 발행 시점 |
| `ComplicationApp/HaruchiComplicationExtension.swift` | 수정 — 템플릿을 걷어내고 3패밀리 |
| `Apps/HaruchiFit/CLAUDE.md` | 수정 — `Common/` 배치 기준 |
| 로드맵 · `TODO.md` | 수정 — WC 완료 |

**표시 로직을 `Common/` 에 두는 이유** — 위젯 타깃에는 테스트 타깃이 없다.
`ComplicationState` 를 내려두면 `watchosTests` 가 `@testable import HaruchiFit_Watch_App` 으로
닿는다. 골프가 같은 이유로 같은 선택을 했다 (`ComplicationState.swift` 주석).

---

## Task 1 — 스냅샷과 표시값 (TDD) — 완료 (`a8401e2`)

**Files:** `Common/` 3개 · `watchosTests/Workout/WorkoutSnapshotTests.swift`

**Produces:** `WorkoutSnapshot` · `WorkoutSnapshotStore` · `ComplicationState`

- [x] **Step 1: 실패하는 테스트를 쓴다** — 저장·로드 왕복, 없을 때 nil, 깨진 데이터는 nil,
      `clear()` 후 nil, `ComplicationState(snapshot: nil)` 이 비활성

- [x] **Step 2: 최소 구현**

```swift
/// 진행 중 세션 스냅샷. 컴플리케이션이 읽는 유일한 데이터원이다 (D-M4 — HealthKit 을 보지 않는다).
struct WorkoutSnapshot: Codable, Equatable {
    let startedAt: Date
    let mode: SegmentKind
    let isPaused: Bool
    /// 스냅샷을 뜬 시점의 경과시간. `capturedAt` 과 짝이라야 의미가 있다.
    let elapsedSeconds: Int
    let capturedAt: Date
}
```

**경과시간을 `startedAt` 하나로 계산하지 않는다.** 일시정지가 있어 `startedAt` 부터의 벽시계
시간은 실제 경과시간보다 길다. 컴플리케이션은 `capturedAt - elapsedSeconds` 를 기준점으로 삼아
`Text(_:style: .timer)` 를 태우고, **정지 중이면 고정 문자열**을 그린다.

```swift
enum WorkoutSnapshotStore {
    static let appGroupID = "group.com.yj.HaruchiFit"
    private static let key = "workoutSnapshot"
    // save / load / clear — 골프 RoundSnapshotStore 와 같은 형태
}
```

- [x] **Step 3: 이 시점에 Task 0 Step 2~4 (사용자 Xcode 작업)** — 폴더가 생겼으니 붙일 수 있다
- [x] **Step 4: 테스트 통과 확인**
- [x] **Step 5: 커밋**

---

## Task 2 — 세션 상태를 발행한다 (TDD) — 완료 (`4c2445f`)

**Files:** `WorkoutSnapshotPublisher.swift` · `WorkoutViewModel.swift` · 스파이 + 테스트

**Consumes:** Task 1

발행 시점은 **상태가 바뀌는 네 곳**이다 — `start()` · `switchMode(to:)` · `togglePause()` · `end()`.
`end()` 는 `clear()` 다.

```swift
protocol WorkoutSnapshotPublishing {
    func publish(_ snapshot: WorkoutSnapshot)
    func clear()
}
```

**뷰모델은 프로토콜에만 의존한다** — 테스트에서 WidgetKit 부작용 없이 호출 시점을 검증하려는
것이고, 골프의 `RoundSnapshotPublishing` 과 같은 이유다.

- [x] Step 1: 스파이 + 실패 테스트 (네 시점 각각 · 종료 시 clear · 전환 시 mode 가 바뀌어 실림)
- [x] Step 2: 구현 — `WKInterfaceDevice` 호출 옆에 한 줄씩
- [x] Step 3: 통과 확인 · 커밋

> **정지/재개만 메서드가 아니라 `session.$isPaused` 스트림에서 보냈다.** `togglePause()` 안에서
> 보내면 세션이 실제로 멈췄는지 모르는 채 값을 지어내게 된다 — 루트 `CLAUDE.md` 가 금지한
> 낙관적 토글이다. 그래서 서비스가 실제로 바꾼 값만 흘려보낸다. 이 경로는 실제 `HKWorkoutSession`
> 없이는 흐르지 않아 유닛 테스트 대신 시뮬레이터에서 App Group 저장으로 확인했다.

> **`elapsedSeconds` 의 출처는 `session.elapsedSeconds`** 다. 경과시간은 워치가 단일 소스라는
> 루트 `CLAUDE.md` 의 워크아웃 계약을 여기서도 지킨다 — 자체 타이머를 두지 않는다.

---

## Task 3 — 컴플리케이션 뷰 — 완료 (`9836055`)

**Files:** `ComplicationApp/HaruchiComplicationExtension.swift`

지금 파일은 Xcode 템플릿(`emoji: "😀"`)이다. 통째로 갈아낀다.

- [ ] **Step 1: `Provider`** — 골프와 같은 정책

  - 세션 없음 → `Timeline(entries: [현재], policy: .never)`. 시간 기반 갱신을 하지 않는다
  - 세션 진행 중 → 엔트리 하나 + `.never`. **경과시간은 `.timer` 스타일이 스스로 흐르므로
    엔트리를 배치로 만들 필요가 없다** (골프의 회전 애니메이션은 하루치에 없다)
  - 갱신의 유일한 트리거는 워치 앱의 `reloadAllTimelines()`

- [ ] **Step 2: 3패밀리** — `accessoryCircular` · `accessoryCorner` · `accessoryRectangular`

  | 상태 | 표시 |
  |---|---|
  | 세션 없음 | 앱 아이콘 + `운동 시작` |
  | 진행 중 | 경과시간 + `근력`/`유산소`, 배경 활성 색 |

  유형 색은 W0 와 같은 규칙을 쓴다 — 근력 오렌지, 유산소 파랑.
  `widgetRenderingMode` 가 `.fullColor` 가 아닐 때 배경색을 빼는 처리도 골프를 따른다.

- [ ] **Step 3: 빌드 + 시뮬레이터에서 눈으로 확인** · 커밋

---

## Task 4 — 문서 갱신 — 완료

- [ ] `Apps/HaruchiFit/CLAUDE.md` 에 `Common/` 배치 기준과 **왜 `Shared/` 가 아닌지**
- [ ] 로드맵 — WC 를 완료로. 남은 13개 → 12개, Phase 번호 당기기.
      **틀렸던 선행 작업 문구를 지운다**
- [ ] `TODO.md` — 진행사항으로 옮기고 Phase 2 를 다음으로
- [ ] 커밋

---

## 검증

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')

xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFit Watch App" -destination "id=$WATCH" build
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiComplicationExtension" -destination "id=$WATCH" build
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFit" -destination "id=$IOS" build
make lint && make format
```

`WorkoutCore` 를 건드리지 않으므로 골프·Ralli 회귀 빌드는 불필요하다.

### 실기기 (필수)

- [ ] 세션을 시작하면 컴플리케이션이 **진행 중**으로 바뀐다 (앱을 안 열어도)
- [ ] 경과시간이 흐르고, **일시정지하면 멈춘다**
- [ ] 근력↔유산소 전환이 컴플리케이션에도 반영된다
- [ ] 종료(저장/버리기 무관)하면 **평상시 표시로 돌아간다**
- [ ] 컴플리케이션을 탭하면 앱이 열린다
- [ ] 워치를 재부팅해도 진행 중 상태가 유지된다 (App Group 저장이 살아 있다)

---

## 스코프 밖

잔디·집계 값(D-M4 로 닫힘) · 백그라운드 HealthKit 배달 · iOS 위젯 ·
세션 복구(크래시 후 이어하기 — 골프엔 있지만 하루치 스펙엔 없다)
