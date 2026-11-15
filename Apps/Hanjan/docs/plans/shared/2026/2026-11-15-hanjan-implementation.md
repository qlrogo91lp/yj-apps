# 한잔 (Hanjan) Implementation Plan

> **For agentic workers:** 이 플랜은 트랙 단위로 Orca 워커(또는 하위 세션)에게 나눠 준다. 워커는 자기 트랙의 Task 만 읽고
> 구현한다. Task 안의 단계는 체크박스(`- [ ]`)로 추적하고, Task 가 끝나면 조율 세션이 Linear YJ-42 체크리스트를 체크한다.

**Goal:** 술자리에서 마신 잔을 워치·폰 어디서든 한 번 눌러 세고, 한도 대비 진행을 보여 주는 iOS + Watch 앱을 이번 주에 TestFlight 에 올리고 심사에 제출한다.

**Architecture:** 잔 하나를 고유 ID 가 붙은 기록으로 다루고, 폰과 워치가 각자 기록 장부(`DrinkLedger`)를 쌓아 서로 병합한다.
화면의 숫자는 저장하지 않고 장부에서 계산한다. 폰이 SwiftData(+CloudKit)로 최종 보관하고, 워치는 진행 중 세션만 갖는다.

**Tech Stack:** SwiftUI · SwiftData · YJKit(`ConnectivityCore`, `PersistenceCore`) · WidgetKit · ActivityKit · UserNotifications · CoreLocation · MapKit. iOS 17.0 / watchOS 10.0.

**Spec:** `Apps/Hanjan/docs/specs/shared/2026/2026-11-15-hanjan-design.md` — 워커는 플랜과 스펙을 함께 읽는다.

## Global Constraints

- 저장소 규약은 루트 `CLAUDE.md` 가 우선한다 (폴더 배치, ViewModel 은 SwiftUI import 금지, 컴포넌트에는 값과 콜백만, 한 파일 한 타입, gitmoji 커밋)
- `project.pbxproj` 를 직접 고치지 않는다. 파일 추가·삭제는 파일시스템으로만. 타깃·폴더 소속 변경은 T0 에서 Xcode GUI 로 끝낸다
- 빌드·테스트는 `-workspace YJApps.xcworkspace`, 시뮬레이터는 UDID (`.github/scripts/pick-simulator.sh`)
- `WorkoutCore` · `WorkoutUI` · HealthKit 을 쓰지 않는다
- `@Model` 은 CloudKit 규칙: 모든 속성 기본값 또는 옵셔널, `@Relationship` 은 옵셔널 + `inverse`, `.unique` 금지
- `ConnectivityService` 는 프로세스당 하나. `onReceive` 등록은 생성한 그 main-queue turn 안에서 끝낸다
- UI 문구: 버튼 라벨은 글자만 (`한 잔`, `취소`, `짠만`). `+` `−` 이모지·아이콘 라벨 없음. 포인트 색 앰버, 경고만 빨강, 어두운 배경
- **버튼 스타일은 Ralli 를 따른다** (참고: `Apps/TennisCounter/WatchApp/Features/Home/HomeView.swift` 의 시작 버튼, `…/Match/Score/Components/UndoButton.swift`, `…/Match/Result/Components/SaveButton.swift`). 메인 색은 앰버 — `BrandColor.amber` 하나만 쓰고 화면에서 색 값을 직접 적지 않는다
  - 주 버튼(`시작` · `한 잔` · `저장` · `다음`): 시스템 `.borderedProminent` + `.tint(BrandColor.amber)`. 글자는 검정(앰버 위 흰 글자는 대비가 낮다)
  - `취소`: Ralli `UndoButton` 과 같은 캡슐 — `.buttonStyle(.plain)`, 흰색 10% 채움 + 흰색 20% 테두리. 비활성은 40% 불투명
  - `짠만`: 같은 캡슐 모양, 채움 없이 앰버 테두리 + 앰버 글자
  - `종료` · 삭제: 같은 캡슐 모양, 채움 없이 `BrandColor.danger` 테두리 + 글자
  - `짠` 캡슐: 입력 화면 맨 위 줄을 좌우로 벌려 왼쪽에 술 종류 캡슐, 오른쪽 끝에 같은 높이의 `짠` 캡슐(`.plain` 버튼). 끔: 보조색 글자 + 흰색 10% 배경 / 켬: 앰버 글자 + 앰버 20% 배경 (HaruchiFit `SessionView.modeButton` 의 색 규칙). 누를 때마다 끔 → 2번 중 1번 → 3번 중 1번 → 끔. 폰은 술 선택 칩 줄의 오른쪽 끝
  - 한도 초과 상태의 주 버튼만 `.tint(BrandColor.danger)`
  - 폰·워치·Live Activity 가 같은 규칙을 쓴다. 버튼은 각 타깃의 `Components/` 에 컴포넌트로 두고 화면마다 다시 꾸미지 않는다
- 화면에 보이는 잔 수는 **소주 환산, 0.5 단위 반올림**. 정수면 소수점 없이 (`5`, `7.5`)
- 음주를 부추기는 문구를 쓰지 않는다
- 알코올 g = `용량(ml) × 도수(%) / 100 × 0.789`
- 한도 단계: 80% 이상 `warning`, 100% 이상 `reached`, 100% 초과 `exceeded`(빨강). 입력은 막지 않는다
- 자동 종료: 마지막 입력(없으면 시작) 후 3시간. 종료 시각은 그 마지막 입력 시각
- 다음 날 회고 알림: 세션 종료 후 6시간 이상 지난 가장 이른 오전 10:00
- 경과 시간은 타이머로 세지 않는다. `startedAt` 에서 계산해 **분 단위**("1시간 12분")로 보이고 화면이 켜져 있는 동안 1분마다 갱신한다. 폰과 워치가 각자 계산한다
- 캘린더·통계에서 세션의 날짜는 **시작 시각** 기준
- 짠 모드: 세션은 항상 끔으로 시작하고 **진행 중 입력 화면에서** 켠다 (`every` = nil(끔) · 2 · 3). 시작 화면에는 선택이 없다. **바꾼 시각 이후에 누른 횟수**로 차례를 계산하고 **주기의 마지막 차례에만 마신다** — 바꾸면 점이 1번부터 다시 시작한다. 양쪽 기기 중 나중에 바꾼 설정이 이긴다.
  `짠만` 은 알코올 0 인 기록으로 장부에 남는다. 한도·통계·술별 잔 수는 실제 마신 잔만 센다

## Review Focus

스펙이 암시하지만 놓치기 쉬운 입력. 각 줄의 테스트는 괄호 안 Task 에 들어 있다.

1. **삭제가 추가보다 먼저 도착한다** — 그 잔은 끝까지 세지지 않아야 한다 (T1 `DrinkLedger`)
2. **세션이 끝난 뒤, 끊겨 있던 워치의 잔이 늦게 도착한다** — 종료된 기록에 합쳐져 잔 수가 맞아야 한다 (T1 병합, T3 저장)
3. **연결이 끊긴 채 폰과 워치가 각각 `시작` 을 눌렀다** — 세션이 둘로 갈라지지 않고 이른 쪽 하나로 합쳐져야 한다 (T1 `LiveSession.absorbing`)
4. **한도 0, 도수 0%, 용량 0ml 인 술** — 0 으로 나누거나 NaN 이 화면에 나오지 않아야 한다. 한도는 최소 1 (T1 계산, T5 입력 검증)
5. **다른 기기에서 넣은 잔을 이쪽에서 취소한다 / 취소를 연타한다** — 항상 "지금 보이는 가장 최근 잔" 하나씩만 지워지고 0 아래로 내려가지 않는다 (T1 `DrinkLedger.last`)

---

## 병렬 실행 구조

```
Wave 0 (직렬)   T0 프로젝트 골격 ──► T1 공용 계약
                                      │
Wave 1 (병렬)   ┌─────────┬──────────┼──────────┬─────────┬──────────┐
                T2 워치   T3 폰 세션  T4 폰 기록  T5 설정·  T6 컴플리  T7 Live      T8 디자인·아이콘·문구
                                                  온보딩    케이션     Activity     (T0 와 동시에 시작 가능)
                └─────────┴──────────┴──────────┴─────────┴──────────┘
Wave 2 (직렬)   T9 조립 ──► T10 실기기 확인 ──► T11 TestFlight · 심사 제출
```

**폴더 소유권** — Wave 1 의 Task 는 서로 다른 폴더만 만진다. 남의 폴더와 `Shared/` · `Common/` 은 읽기만 한다.
계약을 바꿔야 하면 멈추고 조율 세션에 알린다 (다른 트랙이 같은 계약 위에 서 있다).

| Task | 소유 폴더 |
|---|---|
| T1 | `Shared/` `Common/` `iosTests/` |
| T2 | `WatchApp/` |
| T3 | `iOSApp/Services/` `iOSApp/Features/Home/` |
| T4 | `iOSApp/Features/Records/` |
| T5 | `iOSApp/Features/Settings/` `iOSApp/Features/Onboarding/` |
| T6 | `ComplicationApp/` |
| T7 | `LiveActivity/` `iOSApp/LiveActivity/` |
| T8 | `Hanjan.icon/` `APPSTORE.md` 각 타깃 `Assets.xcassets` |
| T9 | `iOSApp/HanjanApp.swift` `iOSApp/RootView.swift` `WatchApp/HanjanWatchApp.swift` |

**브랜치·워크트리** — 통합 브랜치 `feat/hanjan`. T0·T1 은 여기에 직접 커밋한다. Wave 1 은 **워커 슬롯마다** 워크트리 하나
(`../yj-apps-worktrees/hanjan-w1`, `-w2`, …, 브랜치 `feat/hanjan-w1` …)를 T1 커밋에서 파고 끝까지 유지한다.
Task 가 끝날 때마다 조율 세션이 `feat/hanjan` 으로 merge 하고, 워커는 다음 Task 전에 `feat/hanjan` 을 merge 받아 온다.
폴더가 겹치지 않으므로 충돌은 나지 않아야 한다 — 나면 소유권 위반이다. 시뮬레이터는 슬롯마다 다른 UDID 를 쓴다.
PR 은 Wave 2 가 끝난 뒤 `feat/hanjan` → `main` 하나 (본문에 `YJ-42`).

**권장 배정 (Codex 워커 2 + 하위 세션 1)**

| 슬롯 | 순서 | 이유 |
|---|---|---|
| W1 (Codex) | T2 → T6 | 워치 쪽. 컴플리케이션은 워치가 쓰는 스냅샷을 읽는다 |
| W2 (Codex) | T3 → T7 | 폰 세션 쪽. Live Activity 는 폰 세션 상태를 그린다 |
| W3 (하위 세션) | T4 → T5 | SwiftData 만 읽고 쓰는 화면. 세션 코어와 독립 |
| 조율 세션 + 사용자 | T8 | FigCraft 문서 · 아이콘 · 스토어 문구. 코드와 무관하게 처음부터 병행 |

**Linear** — 플랜 승인 뒤 YJ-42 본문에 아래 체크리스트를 넣고, Task 가 merge 될 때마다 하나씩 체크한다.

```
- [ ] T0 프로젝트 골격 (타깃 5개 · 스킴 · 엔타이틀먼트)
- [ ] T1 공용 계약 (장부 · 메시지 · 저장 모델 · 스냅샷)
- [ ] T2 워치 앱
- [ ] T3 폰 세션 · 홈
- [ ] T4 폰 기록 (목록 · 캘린더 · 상세 · 편집 · 회고)
- [ ] T5 폰 설정 · 온보딩
- [ ] T6 컴플리케이션
- [ ] T7 Live Activity
- [ ] T8 디자인 · 아이콘 · 스토어 문구
- [ ] T9 조립
- [ ] T10 실기기 확인
- [ ] T11 TestFlight · 심사 제출
```

---

## Wave 0

### Task 0: 프로젝트 골격

**누가:** 사용자가 Xcode GUI 로 만든다 (타깃 생성은 스크립트로 하지 않는다 — 타깃 규약 문서 §1 의 이름 함정 때문). 워커 하나가 옆에서 검증 명령을 돌린다.

**Files:**
- Create: `Apps/Hanjan/Hanjan.xcodeproj`, `Apps/Hanjan/{iOSApp,WatchApp,Shared,Common,ComplicationApp,LiveActivity,iosTests}/`, 엔타이틀먼트 4개, `Apps/Hanjan/.swiftlint.yml`, `Apps/Hanjan/.swiftformat`, `Apps/Hanjan/CLAUDE.md`
- Modify: `YJApps.xcworkspace/contents.xcworkspacedata`, `Makefile:1` (`APPS` 에 `Hanjan`), 루트 `CLAUDE.md` (저장소 구조 · 스킴 목록 · YJKit 링크 표)

| 타깃 (= 공유 스킴) | 번들 ID | 동기화 폴더 | YJKit |
|---|---|---|---|
| `Hanjan` | `com.yj.Hanjan` | `iOSApp` `Shared` `Common` | ConnectivityCore, PersistenceCore |
| `Hanjan Watch App` | `com.yj.Hanjan.watchkitapp` | `WatchApp` `Shared` `Common` | ConnectivityCore |
| `HanjanComplicationExtension` | `com.yj.Hanjan.watchkitapp.ComplicationApp` | `ComplicationApp` `Common` | — |
| `HanjanLiveActivityExtension` | `com.yj.Hanjan.LiveActivity` | `LiveActivity` `Common` | — |
| `HanjanTests` (iOS 단위 테스트, 호스트 `Hanjan`) | `com.yj.HanjanTests` | `iosTests` | — |

- [ ] **Step 1:** 타깃 규약 문서(`docs/specs/2026/2026-09-03-xcode-target-conventions.md`) 절차대로 프로젝트와 타깃 5개를 만든다. 생성 시트에는 `Hanjan` / `HanjanComplication` / `HanjanLiveActivity` 만 입력한다 (Xcode 가 ` Watch App` · `Extension` 을 덧붙인다)
- [ ] **Step 2:** Capability — iOS: iCloud(CloudKit, 컨테이너 `iCloud.com.yj.Hanjan`), Background Modes(Remote notifications), App Groups(`group.com.yj.Hanjan`), Push 없이 Live Activity(`NSSupportsLiveActivities = YES`). 워치·컴플리케이션: App Groups(`group.com.yj.Hanjan`)
- [ ] **Step 3:** Info.plist 문구 — `NSLocationWhenInUseUsageDescription`: "술자리 장소를 기록에 남기는 데 사용합니다." (iOS · 워치 둘 다)
- [ ] **Step 4:** 스킴 5개를 Shared 로 표시. 배포 타깃 iOS 17.0 / watchOS 10.0
- [ ] **Step 5:** 린트 설정은 HaruchiFit 의 `.swiftlint.yml`(`parent_config`) · `.swiftformat` 을 복사해 경로만 맞춘다. `Apps/Hanjan/CLAUDE.md` 에는 타깃 표와 이 플랜·스펙 경로만 적는다
- [ ] **Step 6: 검증**

```bash
P=Apps/Hanjan/Hanjan.xcodeproj/project.pbxproj
grep -oE 'PRODUCT_BUNDLE_IDENTIFIER = [^;]+;' $P | sort -u          # 위 표의 5개와 일치
grep -oE '(TEST_HOST|BUNDLE_LOADER|INFOPLIST_FILE) = [^;]+;' $P | sort -u
ls Apps/Hanjan/Hanjan.xcodeproj/xcshareddata/xcschemes               # 스킴 5개
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone'); WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme Hanjan -destination "id=$IOS" build
xcodebuild -workspace YJApps.xcworkspace -scheme "Hanjan Watch App" -destination "id=$WATCH" build
make lint
```
Expected: 두 빌드 `BUILD SUCCEEDED`, lint 통과

- [ ] **Step 7:** 커밋 `🔧 chore: 한잔 프로젝트 골격을 추가한다` (브랜치 `feat/hanjan`)

### Task 1: 공용 계약

Wave 1 전체가 이 Task 의 타입 위에 선다. **여기 적힌 이름과 시그니처를 그대로 쓴다.**

**Files:**
- Create: `Shared/Models/{DrinkKind,DrinkPresets,DrinkEntry,DrinkLedger,LiveSession,LimitLevel,SojuFormat}.swift`
- Create: `Shared/Services/Messages/{SessionStartMessage,SessionEndMessage,EntryAddMessage,EntryRemoveMessage,SessionStateMessage,ConfigMessage}.swift`
- Create: `Shared/Persistence/{SessionRecord,EntryRecord,DrinkKindRecord,CompanionRecord,HanjanSchema}.swift`
- Create: `Common/{SessionSnapshot,SessionSnapshotStore,BrandColor}.swift`
- Test: `iosTests/{DrinkLedgerTests,LiveSessionTests,LimitLevelTests,SojuFormatTests,MessageRoundTripTests}.swift`

**Interfaces — Produces:**

```swift
// Shared/Models — 전부 Foundation 만 import, Codable · Equatable · Sendable
struct DrinkKind: Identifiable, Hashable { let id: UUID; var name: String; var abv: Double; var volumeML: Double; var isPreset: Bool; var sortOrder: Int
    var alcoholGrams: Double }                       // 음수·NaN 이면 0
enum DrinkPresets { static let soju, beer, somaek, wine, whisky, other: DrinkKind; static let all: [DrinkKind] }   // id 는 고정 UUID 상수
struct DrinkEntry: Identifiable, Hashable { let id: UUID; let sessionId: UUID; let kindId: UUID; let kindName: String
    let alcoholGrams: Double; let loggedAt: Date; let source: Source; enum Source: String { case phone, watch }
    let isToastOnly: Bool }                          // 짠만: alcoholGrams 0. 구버전 메시지에 키가 없으면 false
struct DrinkLedger {
    mutating func add(_ entry: DrinkEntry)           // 같은 id 재수신 무시, 이미 삭제된 id 면 무시
    mutating func remove(id: UUID)                   // 아직 안 온 id 여도 기억한다
    mutating func merge(_ other: DrinkLedger)
    var activeEntries: [DrinkEntry]                  // 짠만 포함. loggedAt 오름차순, 같으면 id.uuidString
    var drinkEntries: [DrinkEntry]                   // 짠만 제외
    var last: DrinkEntry?                            // 짠만 포함 — 취소는 종류와 무관하게 방금 누른 것
    var totalGrams: Double
    func sojuEquivalent() -> Double                  // totalGrams / DrinkPresets.soju.alcoholGrams
    func countsByKind() -> [KindCount]               // 짠만 제외. struct KindCount { kindId; name; count }, 첫 등장 순
}
struct LiveSession: Identifiable { let id: UUID; let startedAt: Date; var endedAt: Date?; var limit: Double; var currentKindId: UUID
    var toast: ToastSetting                          // struct ToastSetting { let every: Int? /* nil 끔, 2, 3 */; let changedAt: Date }
    mutating func setToast(every: Int?, at: Date)
    var toastProgress: ToastProgress?                // 다음에 누를 차례. struct ToastProgress { filled: Int; total: Int; var isDrinkTurn: Bool { filled == total } }
                                                     // filled = (loggedAt > toast.changedAt 인 activeEntries 수) % every + 1. 끔이면 nil
    func makeEntry(id: UUID, at: Date, kind: DrinkKind, source: DrinkEntry.Source) -> DrinkEntry   // 차례에 따라 한 잔 또는 짠만
    var latitude: Double?; var longitude: Double?; var ledger: DrinkLedger
    var lastActivityAt: Date                         // 마지막 잔 시각, 없으면 startedAt
    func shouldAutoEnd(now: Date) -> Bool            // now - lastActivityAt >= 3시간
    func merging(_ other: LiveSession) -> LiveSession    // 같은 id: 장부 병합, endedAt·좌표는 nil 아닌 쪽, toast 는 changedAt 이 늦은 쪽
    func absorbing(_ other: LiveSession) -> LiveSession  // 다른 id: startedAt 이른 쪽 id 로 합치고 늦은 쪽 잔을 옮겨 온다
}
enum LimitLevel: Equatable { case normal, warning, reached, exceeded
    static func of(equivalent: Double, limit: Double) -> LimitLevel   // limit 은 max(1, limit) 로 본다
    static func crossed(from: LimitLevel, to: LimitLevel) -> LimitLevel?  // warning 또는 reached 로 올라설 때만 그 값
}
enum SojuFormat { static func string(_ equivalent: Double) -> String }   // 0.5 반올림. 5.0→"5", 7.4→"7.5", NaN→"0"

// Shared/Services/Messages — ConnectivityMessage. messageType 은 "hanjan.<이름>"
SessionStartMessage(session: LiveSession)    EntryAddMessage(entry: DrinkEntry)
SessionEndMessage(sessionId: UUID, endedAt: Date)    EntryRemoveMessage(sessionId: UUID, entryId: UUID)
SessionStateMessage(session: LiveSession?)   // nil = 진행 중 세션 없음. .context 로 보낸다
ConfigMessage(kinds: [DrinkKind], limit: Double)     // 폰→워치, .context

// Shared/Persistence — @Model
SessionRecord(id, startedAt, endedAt?, limit, toastOnlyCount, latitude?, longitude?, placeName?, condition: Int?(1...5), memo?, totalGrams, entries: [EntryRecord]?, companions: [CompanionRecord]?)
EntryRecord(id, kindId, kindName, alcoholGrams, loggedAt, source, isToastOnly, session: SessionRecord?)
DrinkKindRecord(id, name, abv, volumeML, isPreset, sortOrder)
CompanionRecord(id, name, sessions: [SessionRecord]?)
enum HanjanSchema { static let models: [any PersistentModel.Type] }
extension SessionRecord { func apply(_ session: LiveSession); var sojuEquivalent: Double; var limitLevel: LimitLevel }

// Common — 확장 타깃도 쓴다. Foundation · SwiftUI(색) 만
struct SessionSnapshot: Codable, Equatable { let isActive: Bool; let equivalent: Double; let limit: Double; let kindName: String; let updatedAt: Date
    static let idle: SessionSnapshot; init(session: LiveSession?, kindName: String) }   // ← init 은 Shared 쪽 extension 파일에 둔다
enum SessionSnapshotStore { static let appGroup = "group.com.yj.Hanjan"; static func write(_:); static func read() -> SessionSnapshot }
enum BrandColor { static let amber, danger, background, surface: Color }
```

전송 규칙(T2·T3 공통): 변경 하나마다 **해당 이벤트 메시지를 `.reliable` 로**, 그리고 **`SessionStateMessage` 를 `.context` 로** 같이 보낸다.
이벤트가 사라져도 다음 상태 메시지가 장부를 통째로 싣고 와 병합으로 복구된다. 수신 측은 언제나 `merging` / `absorbing` 만 쓴다 (덮어쓰기 금지).

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `DrinkLedgerTests`

```swift
func test_removeBeforeAdd_neverCounts()      { var l = DrinkLedger(); l.remove(id: e1.id); l.add(e1); XCTAssertTrue(l.activeEntries.isEmpty) }
func test_duplicateAdd_countsOnce()          { var l = DrinkLedger(); l.add(e1); l.add(e1); XCTAssertEqual(l.activeEntries.count, 1) }
func test_merge_isCommutativeAndIdempotent() { /* a.merge(b) == b.merge(a), a.merge(a) == a */ }
func test_last_isMostRecentAcrossSources()   { /* phone 21:00, watch 21:05 → last == watch 것 */ }
func test_removeLastRepeatedly_stopsAtZero() { /* 2개 넣고 last 를 3번 지워도 크래시 없이 0 */ }
func test_sojuEquivalent_mixedKinds()        { /* 소주 2 + 맥주 1 → (2*soju.g + beer.g) / soju.g, accuracy 0.001 */ }
func test_zeroAbvKind_addsZeroGrams()        { /* abv 0 → totalGrams 변화 없음, NaN 아님 */ }
func test_toastOnly_excludedFromGramsAndKindCounts() { /* 짠만 2 + 소주 1 → totalGrams == soju.g, drinkEntries.count 1, activeEntries.count 3, last 는 짠만일 수 있다 */ }
```

`LiveSessionTests`: `test_toastEvery3_drinksOnThirdTap`(0개 → filled 1 짠만, 1개 → filled 2 짠만, 2개 → filled 3 한 잔, 3개 → 다시 filled 1), `test_toastEvery2_undoRestoresTurn`(짠만·한 잔 뒤 취소 → 다시 한 잔 차례), `test_toastOff_alwaysDrink`(toastProgress nil, makeEntry 는 항상 한 잔), `test_setToastMidSession_restartsCycle`(끔으로 5잔 뒤 every 3 으로 바꾸면 filled 1, 그 뒤 2번 누르면 filled 3 한 잔 차례), `test_merging_laterToastChangeWins`, `test_lateEntryAfterEnd_mergesIntoEndedSession`, `test_absorbing_keepsEarlierIdAndAllEntries`(양쪽 잔 수 합 == 결과 잔 수, 결과 id == 이른 쪽), `test_shouldAutoEnd_after3HoursFromLastEntry`(2:59 false, 3:00 true)
`LimitLevelTests`: limit 8 → 6.3 normal, 6.4 warning, 8.0 reached, 8.1 exceeded / limit 0 → 크래시 없이 limit 1 로 취급 / `crossed(.normal,.warning) == .warning`, `crossed(.warning,.warning) == nil`, `crossed(.reached,.exceeded) == nil`
`SojuFormatTests`: 5.0→"5", 7.4→"7.5", 7.24→"7", .nan→"0"
`MessageRoundTripTests`: 메시지 6종 모두 `Type(from: m.toDictionary()) == m`, 잔 30개가 든 `SessionStateMessage` 포함

- [ ] **Step 2:** 실패 확인 — `xcodebuild -workspace YJApps.xcworkspace -scheme Hanjan -destination "id=$IOS" test -only-testing:HanjanTests` → 컴파일 실패
- [ ] **Step 3:** 위 Interfaces 대로 구현한다. `DrinkLedger` 는 `[UUID: DrinkEntry]` + `Set<UUID>`(삭제된 id). 프리셋 수치: 소주 50ml·16% / 맥주 200ml·4.5% / 소맥 200ml·7% / 와인 150ml·13% / 위스키 30ml·40% / 기타 = 소주와 같음
- [ ] **Step 4:** 테스트 통과 확인 (같은 명령 → `TEST SUCCEEDED`), 워치 스킴 빌드 통과 확인
- [ ] **Step 5:** 커밋 `✨ feat: 한잔 공용 계약(장부·메시지·저장 모델)을 추가한다` → 여기서 Wave 1 워크트리를 판다

---

## Wave 1 (병렬)

모든 Task 공통 마무리: 자기 스킴 빌드 → `make lint` → 커밋 → 조율 세션에 보고(바꾼 파일, 실행한 명령과 결과, 실기기에서만 확인 가능한 항목).
화면은 `~/Workspace/Projects/figcraft/hanjan/mockup/index.html` · `icon.html` 시안을 따른다 (FigCraft 문서 `Hanjan.figcraft` 로 옮겨지면 그쪽). 프리뷰를 화면마다 하나 이상 둔다.

### Task 2: 워치 앱

**Files:** Create `WatchApp/Services/{WatchSessionStore,WatchLocationService,WatchHaptics}.swift`, `WatchApp/Features/Session/{SessionView,SessionViewModel,StartView,CounterPageView,SummaryPageView,KindPickerView,EndConfirmView}.swift`, `WatchApp/Features/Session/Components/{CountDisplay,LimitBar,DrinkButtons}.swift`
(`WatchApp/HanjanWatchApp.swift` 는 T9 가 조립한다 — 템플릿 그대로 두고 `SessionView` 프리뷰로 확인)

**Interfaces:**
- Consumes: T1 전부. `ConnectivityService`
- Produces: `@MainActor final class WatchSessionStore: ObservableObject { init(connectivity: ConnectivityService, now: @escaping () -> Date = Date.init); @Published private(set) var session: LiveSession?; @Published private(set) var kinds: [DrinkKind]; @Published private(set) var limit: Double; func start(); func tapMain(); func undo(); func cycleToast();   /* 끔 → 2 → 3 → 끔 */ func selectKind(_ id: UUID); func end(); func tick() }`

- [ ] 진행 중 세션과 마지막 `ConfigMessage` 를 워치 로컬(App Group UserDefaults, JSON)에 저장하고 앱 재실행 때 복원한다. 폰에서 `ConfigMessage` 가 온 적 없으면 `DrinkPresets.all` · 한도 8
- [ ] 변경마다 T1 전송 규칙대로 보내고 `SessionSnapshotStore.write` + `WidgetCenter.shared.reloadAllTimelines()`
- [ ] `start()` 는 위치를 한 번 요청해 좌표가 오면 세션에 채우고 상태를 다시 보낸다. 권한 거부·실패는 조용히 넘어간다
- [ ] `tick()`(화면이 켜질 때·1분마다): `shouldAutoEnd` 면 `end()`. 폰에서 온 종료·상태 메시지로 끝난 세션은 로컬을 비운다
- [ ] 햅틱: `한 잔` 은 `.click`, `LimitLevel.crossed` 가 warning 이면 `.notification`, reached 면 `.failure`
- [ ] `tapMain()` 은 `session.makeEntry(...)` 로 만든 기록을 넣는다 (짠 모드면 차례에 따라 한 잔 또는 짠만).
- [ ] 짠 모드 화면: 입력 페이지 맨 위 줄 오른쪽의 `짠` 캡슐로 켠다(`cycleToast()`). 바꾼 직후 "짠 모드 3번 중 1번" 2초, 끄면 "짠 모드 끔". 변경은 `SessionStateMessage` 로 전파된다. 켜져 있으면 숫자 옆에 원형 점(`toastProgress.filled` 개 채움 / `total` 개), 주 버튼은 마실 차례 `한 잔`(앰버 채움) · 아니면 `짠만`(테두리만). `짠만` 직후 "짠만 했어요" 2초. 햅틱은 `짠만` 도 `.click`. 시작 화면과 2페이지에는 짠 모드 UI 를 두지 않는다
- [ ] 화면: 시작(앱 이름 + `시작`) / 진행 중(술 이름 ⌄, `5 / 8잔`, 막대, `[취소][한 잔]` 폭 1:3) / exceeded 는 숫자·막대·버튼 빨강 / 취소 직후 "소주 1잔 취소됨" 2초. 진행 중은 가로 페이지 2장(아래에 페이지 점): 1페이지 입력, 2페이지 경과 시간 · 시작 시각("19:30 시작") · 술별 잔 수 · `종료`(빨강 테두리) → 종료 확인. 1페이지에는 종료 버튼을 두지 않는다
- [ ] 검증: `xcodebuild … -scheme "Hanjan Watch App" -destination "id=$WATCH" build`. `WatchSessionStore` 로직 중 시간·병합 분기는 `now` 주입으로 프리뷰/수동 확인 (워치 테스트 타깃은 만들지 않는다 — 병합 규칙 자체는 T1 테스트가 잡는다)

### Task 3: 폰 세션 · 홈

**Files:** Create `iOSApp/Services/{PhoneSessionStore,SessionArchive,LimitNotifier,ReviewReminder,PhoneLocationService,AppSettings}.swift`, `iOSApp/Features/Home/{HomeView,HomeViewModel}.swift`, `iOSApp/Features/Home/Components/{ActiveSessionCard,MonthSummaryCard,RecentSessionRow,KindChips,DrinkButtons}.swift`; Test `iosTests/{SessionArchiveTests,ReviewReminderTests,MonthSummaryTests}.swift`

**Interfaces:**
- Consumes: T1 전부, `ConnectivityService`, `PersistenceContainerFactory`
- Produces:
  - `@MainActor final class PhoneSessionStore: ObservableObject { init(connectivity:, archive: SessionArchive, settings: AppSettings, now:); @Published private(set) var session: LiveSession?; var onChange: ((LiveSession?) -> Void)?; func start(); func tapMain(); func undo(); func cycleToast(); func selectKind(_:); func end(); func tick(); func pushConfig() }` — 시그니처는 T2 와 같은 모양
  - `SessionArchive { init(context: ModelContext); func save(_ session: LiveSession) throws; func seedPresetsIfNeeded() throws; func kinds() throws -> [DrinkKind] }` — `save` 는 id 로 upsert 하고 잔은 장부와 일치시킨다 (종료된 세션에 늦게 온 잔 포함)
  - `AppSettings: ObservableObject { @Published var limit: Double /* 최소 1 */; @Published var hasOnboarded: Bool; @Published var alertsEnabled: Bool }` (UserDefaults)
  - `LimitNotifier.notify(_ level: LimitLevel)` — 문구: warning "한도의 80%입니다. 천천히 드세요." / reached "오늘 한도에 도달했습니다."
  - `ReviewReminder.fireDate(endedAt: Date, calendar: Calendar) -> Date`, `schedule(sessionId:endedAt:)` — 알림 "어제 어땠나요?", userInfo 에 `sessionId`
  - `MonthSummary { let count: Int; let equivalent: Double; let exceededCount: Int; static func of(_ sessions: [SessionRecord], month: Date, calendar: Calendar) -> MonthSummary }`

- [ ] 테스트 먼저: `SessionArchiveTests`(인메모리 컨테이너) — `save` 두 번에 레코드 1개 / 종료 후 잔 하나 더 든 세션을 다시 `save` 하면 `EntryRecord` 수와 `totalGrams` 가 늘어난다 / 삭제된 잔은 레코드에서 빠진다. `ReviewReminderTests` — 23:00 종료 → 다음 날 10:00 / 02:00 종료 → 같은 날 10:00 / 05:00 종료 → 다음 날 10:00. `MonthSummaryTests` — 10/31 23:50 시작·11/1 종료 세션은 10월에 센다 / exceeded 만 `exceededCount`
- [ ] 수신 처리: 같은 id 는 `merging`, 다른 id 의 진행 중 세션은 `absorbing`. 이미 종료·보관된 세션 id 로 잔이 오면 진행 중 세션을 건드리지 않고 `SessionArchive.save` 로 그 기록만 고친다
- [ ] 변경마다: 전송 규칙 → `archive.save` → `LimitLevel.crossed` 면 `LimitNotifier` → `onChange` 호출. 종료 시 `ReviewReminder.schedule`
- [ ] 워치 메시지로 백그라운드에서 깨어났을 때도 같은 경로를 탄다 (UI 없이 store 만으로 동작해야 한다)
- [ ] `pushConfig()` 는 술 목록·한도가 바뀔 때와 앱 실행 때 `ConfigMessage` 를 보낸다
- [ ] 짠 모드: 진행 중 화면의 술 선택 칩 줄 오른쪽 끝에 `짠` 캡슐. 켜면 워치와 같은 원형 점 + `한 잔`/`짠만` 버튼. 홈 대기 화면에는 두지 않는다
- [ ] 홈: 대기(한도, `시작`, 이번 달 카드, 최근 기록 3개) / 진행 중(경과 시간 · 시작 시각, `5 / 8잔` + 막대, 술별 잔 수, 술 선택 칩 + 더보기 시트, `[취소][한 잔]`, 종료). 최근 기록·이번 달 카드는 `@Query` 로 읽는다
- [ ] 검증: `… -scheme Hanjan -destination "id=$IOS" test -only-testing:HanjanTests` → `TEST SUCCEEDED`

### Task 4: 폰 기록

**Files:** Create `iOSApp/Features/Records/{RecordsView,RecordsViewModel}.swift`, `Records/List/RecordListView.swift`, `Records/Calendar/{RecordCalendarView,Components/CalendarGrid,Components/DaySummaryCard}.swift`, `Records/Detail/{RecordDetailView,Components/SessionMap,Components/KindCountList}.swift`, `Records/Edit/{EntryEditView,ReviewFormView,Components/ConditionPicker,Components/CompanionField}.swift`; Test `iosTests/{CalendarMarksTests,EntryEditTests}.swift`

**Interfaces:**
- Consumes: T1 의 `@Model` · `LimitLevel` · `SojuFormat` · `DrinkLedger`. T3 의 타입은 쓰지 않는다 (SwiftData 를 직접 읽고 쓴다)
- Produces: `RecordsView()` · `ReviewFormView(sessionId: UUID, onDone: () -> Void)` — T9 가 탭과 알림 딥링크에 건다

- [ ] 테스트 먼저: `CalendarMarksTests` — 날짜별 표시(`none / drank / exceeded`)를 내는 순수 함수 `CalendarMarks.of(_ sessions:, month:, calendar:) -> [Date: Mark]`, 하루에 세션 둘이고 하나만 exceeded 면 exceeded. `EntryEditTests` — 스테퍼로 술별 잔 수를 고치는 순수 함수 `EntryEdit.adjust(_ entries:, kind: DrinkKind, to count: Int, sessionId:, now:) -> [DrinkEntry]` 는 늘릴 때 새 id 를 만들고 줄일 때 최근 것부터 지우며 0 아래로 내려가지 않는다
- [ ] `목록 | 캘린더` 세그먼트. 캘린더는 Ralli `Apps/TennisCounter/iOSApp/Features/History/Calendar/` 를 참고해 복사·수정한다 (import 하지 않는다). 마신 날 앰버 점, exceeded 빨간 점, 달 위에 `6회 · 41잔 · 한도 초과 2회`
- [ ] 상세: 지도(좌표 없으면 지도 영역 자체를 숨긴다), 소주 환산 잔 수, 술별 잔 수, `toastOnlyCount > 0` 이면 "짠만 8번" 한 줄, 상태, 함께한 사람, 메모, 삭제
- [ ] 회고 폼: 상태 5단계(멀쩡 / 기분 좋음 / 취함 / 많이 취함 / 필름 끊김, 글자 버튼), 함께한 사람(기존 `CompanionRecord` 고르기 + 새로 입력), 장소 이름(비어 있고 좌표가 있으면 역지오코딩으로 채움), 메모. 전부 선택 입력
- [ ] 검증: T3 와 같은 테스트 명령

### Task 5: 폰 설정 · 온보딩

**Files:** Create `iOSApp/Features/Settings/{SettingsView,SettingsViewModel,KindListView,KindEditView}.swift`, `iOSApp/Features/Onboarding/{OnboardingView,OnboardingViewModel}.swift`, `Onboarding/Components/{LimitStepPage,BothDevicesPage,ToastModePage,PermissionPage}.swift`; Test `iosTests/KindValidationTests.swift`

**Interfaces:**
- Consumes: T1 의 `DrinkKindRecord` · `DrinkKind` · `SojuFormat`
- Produces: `SettingsView(limit: Binding<Double>, alertsEnabled: Binding<Bool>, onKindsChanged: () -> Void)` · `OnboardingView(onFinish: (_ limit: Double) -> Void)` — `AppSettings` 를 직접 알지 않는다. T9 가 잇는다

- [ ] 테스트 먼저: `KindValidation.validate(name:abv:volumeML:) -> Result<Void, KindValidationError>` — 이름 공백만 → 실패 / abv 0 이하 또는 100 초과 → 실패 / 용량 0 이하 또는 2000 초과 → 실패 / 정상값 통과
- [ ] 술 목록: 프리셋은 수정만(삭제 불가), 사용자 추가는 삭제 가능. 편집 화면에 "소주 약 N잔" 미리보기
- [ ] 한도: 1~30, 0.5 단위 스테퍼
- [ ] 온보딩 4장: ① "평소 주량은 소주 몇 잔인가요?"(기본 8) ② "폰에서도, 워치에서도" — 폰과 워치 미니 화면을 나란히(같은 `5 / 8잔`), "어느 쪽에서 눌러도 같이 올라가요.", "워치가 없어도 폰만으로 쓸 수 있어요." ③ 짠 모드 — 제목 "친구와 속도가 달라도 괜찮아요", 기기와 무관한 카드 3컷(점 1/3 `짠만` → 2/3 `짠만` → 3/3 `한 잔`), 강조 문장 "점이 다 차면 마실 차례입니다." ④ 알림·위치 권한 — 이유 한 줄씩 보이고 버튼을 눌렀을 때만 시스템 권한 창을 띄운다. 건너뛰기 가능
- [ ] 검증: T3 와 같은 테스트 명령

### Task 6: 컴플리케이션

**Files:** Create `ComplicationApp/{HanjanComplicationExtensionBundle,HanjanComplication,ComplicationViews}.swift` (템플릿 파일 대체)

**Interfaces:** Consumes `SessionSnapshotStore.read()` · `SojuFormat` · `BrandColor`. Produces 없음

- [ ] HaruchiFit `ComplicationApp/` 구조를 따른다. family: `accessoryCircular` · `accessoryCorner` · `accessoryRectangular` · `accessoryInline`
- [ ] 세션 없음: 잔 아이콘만 / 진행 중: `5/8` + 진행 링(직사각형은 "한잔 · 5 / 8잔" + 막대). exceeded 는 빨강(틴트 모드에서는 시스템 틴트를 따른다)
- [ ] 타임라인은 항목 하나 + `.never`. 갱신은 워치 앱의 `reloadAllTimelines()` 에 맡긴다
- [ ] 탭하면 워치 앱이 열린다
- [ ] 검증: `… -scheme HanjanComplicationExtension -destination "id=$WATCH" build`, 프리뷰 4 family × (대기 / 진행 / 초과)

### Task 7: Live Activity

**Files:** Create `LiveActivity/{HanjanLiveActivityBundle,HanjanLiveActivity,HanjanActivityAttributes,AddDrinkIntent}.swift`, `LiveActivity/Components/{LockScreenView,IslandViews}.swift`, `iOSApp/LiveActivity/LiveActivityController.swift`

**Interfaces:**
- Consumes: `LiveSession` · `LimitLevel` · `SojuFormat` · `BrandColor`
- Produces: `@MainActor final class LiveActivityController { func sync(_ session: LiveSession?, kindName: String) }` — 세션이 있고 Activity 가 없으면 시작(앱이 foreground 가 아니어서 실패하면 조용히 넘어가고 다음 `sync` 에서 다시 시도), 있으면 update, 세션이 nil 이면 end. `AddDrinkIntent: LiveActivityIntent` 는 `static var handler: (@MainActor () -> Void)?` 를 호출한다 — T9 가 `PhoneSessionStore.tapMain` 을 꽂는다. 버튼 라벨은 `toastProgress` 에 따라 `한 잔` / `짠만`
- `HanjanActivityAttributes` 는 iOS 앱과 확장이 같이 써야 한다. Ralli 가 `TennisActivityAttributes` 를 두 타깃에 넣은 방식을 그대로 따른다

- [ ] Ralli `TennisLiveActivity/` · `iOSApp/Services/LiveActivityService.swift` 를 참고해 복사·수정
- [ ] 잠금화면: "한잔 · 소주" / `5 / 8잔` + 막대 / 오른쪽 `한 잔` 버튼. 다이내믹 아일랜드 컴팩트(좌 잔 아이콘, 우 `5/8`) · 확장 · 미니멀. exceeded 는 빨강
- [ ] 검증: `… -scheme HanjanLiveActivityExtension -destination "id=$IOS" build`, 프리뷰(진행 / 초과). **일정이 밀리면 `AddDrinkIntent` 와 버튼만 뺀다 — 표시는 남긴다**

### Task 8: 디자인 · 아이콘 · 스토어 문구

코드 트랙과 무관. T0 와 동시에 시작한다. 조율 세션 + 사용자.

- [x] HTML 시안 두 파일을 `~/Workspace/Projects/figcraft/hanjan/mockup/` 으로 옮긴다
- [ ] FigCraft MCP 로 `~/Workspace/Projects/figcraft/hanjan/Hanjan.figcraft` 에 색·글자 스타일과 컴포넌트(버튼 4종 `한 잔`·`짠만`·`취소`·`종료` — Global Constraints 의 버튼 스타일대로, 진행 막대, 원형 점, 카드, 칩)를 만들고 화면을 옮긴다. 이 파일은 git 에 넣지 않는다 — 결과물만 저장소로 가져온다
- [ ] 아이콘(변형 a) → Icon Composer `Apps/Hanjan/Hanjan.icon`, 워치·컴플리케이션용 잔 심볼 에셋. 그 전까지 코드는 임시 아이콘으로 간다
- [ ] `Apps/Hanjan/APPSTORE.md` — 이름 · 부제 · 키워드 · 프로모션 · 설명 · 출시 노트 · 스크린샷 캡션, `ko` · `en-US`. 다른 앱의 파일 형식을 따른다
- [ ] 스크린샷(iPhone · Watch) — T9 뒤에 시뮬레이터에서 찍는다

---

## Wave 2 (직렬)

### Task 9: 조립

**Files:** Modify `iOSApp/HanjanApp.swift`, Create `iOSApp/RootView.swift`, Modify `WatchApp/HanjanWatchApp.swift`

- [ ] iOS 루트: `PersistenceContainerFactory.make(for: HanjanSchema.models)` → `SessionArchive.seedPresetsIfNeeded()` → `ConnectivityService` 하나 → `PhoneSessionStore`(생성한 turn 안에서 `onReceive` 등록이 끝나야 한다) → `pushConfig()`
- [ ] `store.onChange = { liveActivity.sync($0, kindName:) }`, `AddDrinkIntent.handler = { store.tapMain() }`
- [ ] 탭: 홈 / 기록 / 설정. `hasOnboarded == false` 면 온보딩 → `onFinish` 에서 한도 저장. 설정의 `onKindsChanged` · 한도 변경 → `store.pushConfig()`
- [ ] 회고 알림을 누르면 `ReviewFormView(sessionId:)` 를 시트로 띄운다
- [ ] 앱이 활성화될 때와 1분 타이머로 `store.tick()` (양쪽)
- [ ] 워치 루트: `ConnectivityService` 하나 → `WatchSessionStore` → `SessionView`
- [ ] 검증: 스킴 5개 빌드, `HanjanTests` 전체, `make lint`, `make format`. 시뮬레이터 한 쌍(폰+워치)에서 시작 → 한 잔 3번 → 취소 → 종료가 양쪽에 같은 숫자로 보이는지

### Task 10: 실기기 확인 (사용자)

시뮬레이터로 확인되지 않는 것. 결과를 `Apps/Hanjan/docs/logs/2026/` 에 남긴다.

- [ ] 워치에서 시작 → 폰이 잠긴 채 잔 수가 따라온다 / 폰 앱을 열면 Live Activity 가 뜬다
- [ ] 폰을 두고 멀어져 워치로 3잔 → 돌아오면 폰에 3잔이 합쳐진다. 그사이 폰에서 누른 잔도 사라지지 않는다
- [ ] 양쪽에서 번갈아 취소 — 0 아래로 안 내려가고 양쪽 숫자가 같다
- [ ] 짠 모드 3번 중 1번으로 9번 누르면 3잔. 중간에 취소하면 차례가 한 칸 돌아간다. 폰과 워치의 점·버튼 글자가 같다
- [ ] 워치에서 `짠` 캡슐로 짠 모드를 켜면 폰도 따라 바뀌고 점이 1번부터 시작한다. 끄면 양쪽 버튼이 `한 잔` 으로 돌아온다
- [ ] 한도 80% · 100% 에서 알림과 햅틱. 초과 시 빨강
- [ ] 컴플리케이션 숫자가 한 잔마다 바뀐다. 시계 화면에서 눌러 앱으로 들어간다
- [ ] 잠금화면 `한 잔` 버튼
- [ ] 종료 후 다음 날 10:00 알림 → 회고 폼. 장소 이름이 자동으로 채워진다
- [ ] 위치·알림 권한을 거부한 상태로 처음부터 끝까지
- [ ] iCloud 로그인 기기에서 앱 삭제 후 재설치 → 기록이 돌아온다

### Task 11: TestFlight · 심사 제출

- [ ] `feat/hanjan` → `main` PR (본문 `YJ-42`), 일반 merge commit
- [ ] App Store Connect 앱 등록(번들 ID 4개 · App Group · iCloud 컨테이너), 아카이브 업로드, TestFlight 내부 테스트
- [ ] 연령 등급 설문(음주 관련 항목 → 17+ 예상), 개인정보 처리(위치: 앱 기능용, 추적 없음), `APPSTORE.md` 문구·스크린샷 붙여 넣기
- [ ] 가이드라인 1.4.3 원문을 직접 확인하고 심사 노트에 "음주량을 줄이기 위한 한도 관리 앱이며 음주를 권하는 기능이 없다" 를 적는다
- [ ] 심사 제출. YJ-42 를 Done 으로

---

## 스펙 대비 확인

| 스펙 항목 | Task |
|---|---|
| 세션 시작·종료·자동 종료, 위치 | T1 · T2 · T3 |
| 한 잔 · 취소 · 술 종류 변경 | T1 · T2 · T3 |
| 소주 환산 · 프리셋 · 사용자 술 | T1 · T5 |
| 한도 알림 · 햅틱 · 빨강 | T1 · T2 · T3 |
| 다음 날 회고 | T3(알림) · T4(폼) · T9(딥링크) |
| 기록 목록 · 캘린더 · 상세 · 잔 수 편집 | T4 |
| 이번 달 통계 | T3 |
| 온보딩 4장 · 설정 | T5 |
| 짠 모드 | T1(차례 계산) · T2 · T3 · T5(온보딩) · T7(버튼 라벨) |
| 컴플리케이션 | T6 |
| Live Activity (+ 한 잔 버튼) | T7 |
| 동기화 B안 | T1(규칙) · T2 · T3 |
| 아이콘 · FigCraft 문서 · 스토어 문구 | T8 |
| 출시 | T10 · T11 |
