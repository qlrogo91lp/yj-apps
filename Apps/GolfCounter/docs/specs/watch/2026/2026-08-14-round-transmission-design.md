# 워치 라운드 종료·전송 설계 (홀 수 선택 + 종료 요약 + 발신)

- 작성일: 2026-08-14
- 참조: `2026-07-31-golfcounter-rebuild-design.md` §3·§4·§5, `2026-08-13-watch-folder-structure-design.md` §9, `2026-08-13-round-viewmodel-split-design.md` §8
- 대체: `2026-08-05-watch-round-transmission.md`(plan ④). 그 문서의 설계 결정은 대부분 유효하나 폴더 개편(③-c)·ViewModel 분리(③-d) 이후 파일 경로와 상태 소유권이 어긋나 이 문서로 다시 쓴다. **기존 plan ④ 문서는 이 spec 기준으로 재작성한다.**
- 선행: ③-c(PR #10)·③-d(PR #12) 머지 완료

## 1. 목표

워치에서 만든 라운드가 iOS로 넘어갈 수 있게 한다. 세 조각이다.

1. 라운드 시작 시 **9홀/18홀 선택** — "다음" 버튼에 상한이 없어 마지막 홀에서 한 번 더 누르면 빈 홀이 무한정 생기는 현재 문제를 막는다
2. 라운드 종료 시 **확인 → 요약 화면**
3. `.reliable` **발신** — 받는 쪽(iOS)은 plan ⑤ 범위다

## 2. 유지되는 설계 결정

기존 plan ④가 브레인스토밍으로 확정한 것 중 구조 변경과 무관한 것들이다. 근거는 그 문서에 있고 여기서 반복하지 않는다.

| # | 결정 |
|---|------|
| 2 | 미기록 홀은 전송 직전에 트림한다 — 배열 말단에서부터 `par == 0`인 홀 제거. `par == 0`이면 파 선택 화면이 떠 카운터에 접근할 수 없으므로 `score`·`putts`도 0 → **무손실** |
| 3 | 라운드 `id`는 시작 시 생성해 스냅샷에 싣는다 — 복구를 넘어 유지되어 재전송을 iOS가 걸러낸다 |
| 4 | "라운드 종료"에 확인 다이얼로그. 트림 후 실제 기록 홀 수를 문구에 명시 |
| 6 | 전송 없이 요약을 벗어나면 스냅샷을 남긴다 — 라운드가 조용히 사라지는 경로를 만들지 않는다 |
| 7 | 홈의 복구 시도는 앱 실행당 1회 |
| 9 | "저장 & 전송" 버튼은 항상 활성. 메트릭 수집 중이면 "전송 중…" 표시 후 도착하는 대로 발신 |
| 10 | 기록 홀 0개면 전송하지 않는다. 버튼이 "저장 없이 종료"로 바뀌고 스냅샷만 지운다 |

## 3. 이번에 다시 정한 것

### 3.1 홀 수 상한은 `HoleProgress`가 소유한다

```swift
struct HoleProgress: Equatable {
    let holeCount: Int                                          // 9 또는 18, 불변
    var canGoToNextHole: Bool { currentHoleIndex + 1 < holeCount }

    mutating func advanceToNextHole() {
        guard canGoToNextHole else { return }
        currentHoleIndex += 1
        ensureCapacityForCurrentHole()
    }
}
```

배열 길이·인덱스 관리가 이미 이 타입 책임이므로 상한도 같이 둔다. 호출부가 가드를 빠뜨려도 타입이 스스로 막는다 — ④가 종료·전송 경로를 새로 얹어 호출부가 늘어나는 시점이라 이 성질이 특히 값을 한다.

대가: `init()` → `init(holeCount:)`, 복구 init에도 `holeCount:` 추가. `HoleProgressTests` 17건은 기계적 치환이다.

대안으로 검토한 것 — `RoundViewModel`이 소유하면 테스트 17건이 무변경이지만 배열을 늘리는 타입이 자기 상한을 모르는 상태가 남는다. optional(`Int?`, nil = 상한 없음)은 테스트도 무변경이고 상한도 타입 안이지만, 실제로는 절대 안 생기는 "상한 없는 HoleProgress" 상태를 영구히 이고 간다.

### 3.2 요약은 3페이지 TabView를 통째로 교체한다

`phase == .summary`면 `RoundSessionView`가 TabView 대신 `SummaryView`를 그린다. 요약 시점엔 워크아웃이 이미 끝나 컨트롤 페이지의 일시정지·종료 버튼과 메트릭 페이지의 실시간 수치가 둘 다 의미를 잃으므로, 그쪽으로 스와이프할 수 있으면 안 된다.

**함정**: `Group`으로 분기를 감싸면 modifier가 각 분기에 개별 적용되어 전환 시 `onAppear`가 재발화하고 `startRound()`가 다시 돈다. `ZStack` 같은 실제 컨테이너로 감싸 수명주기 modifier를 한 곳에 고정한다.

### 3.3 요약 화면은 오버파 중심

```
      18홀 완료
         +17
     89타 · 34퍼트

    [ 저장 & 전송 ]
```

- **N홀 완료** — 트림 후 실제 기록 홀 수. 무엇이 전송되는지를 발신 직전에 다시 확인시킨다
- **오버파를 가장 크게** — 카운팅 화면의 링과 스코어카드 합계가 이미 파 대비를 중심 어휘로 쓴다. 표기는 `ScoreFormat.relativeToPar(_:)` 재사용
- **총타수 · 총퍼트**를 그 아래 한 줄
- 골프장명은 값이 있을 때만. MapKit 감지(⑧) 전까지 항상 `nil`이라 실제로는 렌더되지 않는다

워크아웃 메트릭(칼로리·심박·거리·시간)은 **화면에 띄우지 않고 전송 페이로드에만** 싣는다. `stopWorkout()`이 1~3초 걸려 도착하므로 화면에 띄우면 대기·도착·미도착 세 상태를 설계해야 하는데, 같은 정보를 iOS 상세 화면이 곧 보여줄 예정이라 값에 비해 비용이 크다.

### 3.4 홀 수 선택은 홈 화면의 값 버튼

별도 화면을 만들지 않는다. 지금 담을 게 9/18 하나뿐이라 화면값을 못 하고, 테니스처럼 매치 전 세팅 화면이 이미 있는 것도 아니다.

```
   Golf Counter
  [ 18홀 시작 ]        ← 탭: RoundSessionView(holeCount: 18)
   홀 수     [ 18 ]    ← 탭: 9 ⇄ 18, 위 버튼 문구도 따라 바뀐다
```

- **라벨 + 값 버튼** — tennis_counter `ModeView`의 게임 수(4→5→6) 컨트롤과 같은 모양. 홀 수는 불리언이 아니라 값이므로 스위치보다 성격이 맞고, 현재 값이 숫자로 항상 보인다
- **시작 버튼이 홀 수를 말한다** (`18홀 시작`) — 오발 위험이 가장 낮다
- **영속 저장 없음** — 앱을 열 때마다 18홀이 기본. 상태가 누적되지 않아 항상 같은 지점에서 시작한다
- 복구된 라운드는 이 값을 무시하고 스냅샷의 `holeCount`를 쓴다

**후속**: MapKit 골프장 감지(⑧)가 들어와 골프장 확인·입력이 생기면, 그때 홀 수와 함께 담는 "라운드 준비" 화면으로 승격한다. 이 컨트롤을 그대로 들어 옮기면 된다.

### 3.5 스냅샷 하위호환 (신규 발견)

`RoundSnapshotStore.load()`는 `try?`로 디코딩해 실패를 조용히 `nil`로 만든다. `RoundSnapshot`에 `id`·`holeCount`를 그냥 추가하면 **라운드 진행 중에 앱을 업데이트한 경우 스냅샷 디코딩이 실패해 라운드가 소리 없이 사라진다** — 결정 6이 막으려던 바로 그 경로다.

`init(from:)`만 직접 작성해 `decodeIfPresent`로 읽고, 없으면 아래 값으로 채운다. 인코딩은 합성된 것을 그대로 쓴다.

- **`id`** — 새로 생성한다. 스냅샷에 남아 있다는 것은 아직 전송되지 않았다는 뜻이므로(전송이 성공하면 스냅샷을 지운다) 새 `id`로 보내도 iOS에 중복이 생기지 않는다.
- **`holeCount`** — `max(18, holeScores.count)`. 상한이 없던 시절 라운드는 "다음"을 계속 눌러 **18홀을 넘겼을 수 있다.** 그냥 18로 채우면 `currentHoleIndex`가 상한 밖에 놓여 이미 친 홀이 잘린다. 실제 기록 길이를 하한으로 잡아 기존 데이터를 보존한다.

### 3.6 진행 중 스냅샷이 있는데 새 라운드를 시작하는 경우 (신규 발견)

결정 6에 따라 전송 없이 요약을 벗어나면 스냅샷이 남는다. 그 상태로 홈에서 새 라운드를 시작하면 `start()`가 곧바로 새 스냅샷을 발행해 이전 라운드를 덮어쓴다.

`N홀 시작`을 눌렀을 때 스냅샷이 남아 있으면 **확인 다이얼로그**를 띄운다: `"진행 중인 라운드가 있습니다. 새로 시작하면 지워집니다."` 종료 확인에서 이미 쓰는 패턴이라 새 개념이 아니다.

대안으로 검토한 것 — 스냅샷이 있으면 시작 버튼을 "라운드 이어하기"로 바꾸는 방식은 안전하지만 새 라운드를 시작할 길이 막힌다. 그냥 덮어쓰는 것은 결정 6을 무력화한다.

## 4. 데이터 모델

### RoundSnapshot (`Shared/Models/`, 수정)

```swift
var id: UUID          // 신규 — 라운드 시작 시 생성, 복구를 넘어 유지
var holeCount: Int    // 신규 — 9 또는 18
// 기존: startedAt, courseName, currentHoleIndex, holeScores, holePars, puttCounts
```

**`trimmed() -> RoundSnapshot`** — 배열 말단부터 `par == 0`인 홀을 제거하고 `currentHoleIndex`를 남은 범위로 클램프한다. 중간에 낀 `par == 0` 홀은 건드리지 않는다(사용자가 의도적으로 건너뛴 홀일 수 있다). `Shared`의 순수 함수라 단독 테스트가 쉽고 iOS도 필요하면 쓸 수 있다.

### RoundMetrics (`Shared/Models/`, 신규)

`Foundation`만 쓰는 순수 struct: `calories` · `avgHeartRate` · `distanceMeters` · `steps`.

`WorkoutResult`를 그대로 싣지 않는 이유: `Shared/`에 `import WorkoutCore`를 두면 **iOS 타깃 빌드가 깨진다**(iOS는 WorkoutCore를 링크하지 않는다). `WorkoutResult → RoundMetrics` 변환은 워치 타깃 안에 둔다.

### RoundCompletedMessage (`Shared/Services/ConnectivityMessages.swift`, 신규)

`ConnectivityCore`의 `ConnectivityMessage`를 채택한다(`messageType` · `init?(from:)` · `toDictionary()`). 페이로드는 `GolfRound` 필드와 1:1 — `id` · `startedAt` · `endedAt` · `courseName` · 세 배열 · `calories` · `avgHeartRate` · `distanceMeters` · `steps`.

`WorkoutResult.durationSeconds`·`totalCaloriesBurned`는 `GolfRound`에 대응 필드가 없어 싣지 않는다(소요 시간은 `endedAt - startedAt`으로 파생).

**`endedAt`은 종료 확인을 누른 시점**이다 — 요약 화면에 머문 시간이나 전송이 늦어진 시간이 라운드 길이에 섞이지 않는다. `phase = .summary`로 전환할 때 `RoundViewModel`이 기록한다.

## 5. 타깃 링크 제약 (이 설계에서 유일하게 pbxproj를 건드리는 곳)

`Shared/`는 `PBXFileSystemSynchronizedRootGroup`으로 네 곳(iOS·Watch·Complication·테스트)에 붙어 있는데 SPM 링크는 타깃마다 다르다.

| 타깃 | 링크된 ralli-kit |
|------|---------------------|
| `GolfCounter` (iOS) | ConnectivityCore · PersistenceCore |
| `GolfCounter Watch App` | ConnectivityCore · WorkoutCore · WorkoutUI |
| `ComplicationAppExtension` | **없음** (Frameworks 빌드 페이즈가 비어 있다) |

따라서 `import ConnectivityCore`를 하는 `ConnectivityMessages.swift`를 `Shared/`에 두면 컴플리케이션 타깃 빌드가 깨진다. `Shared` 동기화 그룹에 `PBXFileSystemSynchronizedBuildFileExceptionSet`을 추가해 이 파일을 `ComplicationAppExtension`에서 제외한다. `ComplicationApp/Info.plist`가 이미 같은 방식으로 처리돼 있어 새 메커니즘은 아니다.

## 6. 상태 소유권

| 상태 | 소유 |
|------|------|
| `holeCount` 상한, `canGoToNextHole` | `HoleProgress` |
| 라운드 `id`, `phase`(+`.summary`), `metrics`, `transmitter` | `RoundViewModel` |
| 트림 | `RoundSnapshot.trimmed()` |
| 복구 판단(스냅샷 유무 · 1회 가드), 홈의 홀 수 선택값 | `HomeViewModel` (신규) |

`RoundViewModel`은 ③-d에서 확립한 파사드를 유지한다 — 유일한 `ObservableObject`이고 `HoleProgress`·`StrokeUndo`는 내부 구현이다.

`HomeViewModel`을 새로 두는 이유: 결정 7의 1회 가드가 없으면 요약에서 전송 없이 나왔을 때 홈에 도착하자마자 다시 라운드로 끌려 들어가 빠져나올 수 없다. 지금은 `HomeView`의 `@State` 안이라 테스트가 안 된다.

## 7. 화면 흐름

```
앱 실행
  └ HomeViewModel.resumeIfNeeded()  (앱 실행당 1회)
      스냅샷 있음 → RoundSessionView(resuming:)   ← 홀 수는 스냅샷 값

홈
  [N홀 시작] ─ 스냅샷 있음? ─예→ "새로 시작하면 지워집니다" 확인
             └────────────아니오→ RoundSessionView(holeCount:)

세션 (phase != .summary)          [라운드 종료] → "N홀이 기록됩니다" 확인
┌──────────────────┐                     │
│ 0 컨트롤          │                     ├ stopWorkout() 시작 (async)
│ 1 파선택/카운팅    │  ─────────────>      └ phase = .summary
│ 2 메트릭          │
└──────────────────┘

요약 (phase == .summary)
  [저장 & 전송] ─ metrics 도착? ─예→ send(.reliable) → 스냅샷 삭제 → 홈
                              └아니오→ "전송 중…" → 도착 후 위와 동일
  이탈(edge swipe)          → 스냅샷 유지 → 다음 실행 때 복구
```

발신은 `RoundTransmitting` 프로토콜 뒤에 둔다(`RoundSnapshotPublishing`과 같은 방식) — ViewModel 테스트가 WatchConnectivity 없이 돈다. `.reliable`은 `sendMessage` 실패 시 `transferUserInfo`로 큐잉되고 시스템이 배달을 보장하므로 워치 쪽 재시도 로직은 만들지 않는다.

## 8. 엣지 케이스

| 상황 | 처리 |
|------|------|
| `stopWorkout()`이 `nil` (HealthKit 거부 · 워크아웃 미시작 · 복구 라운드) | `RoundMetrics` 전부 0으로 전송. 요약은 메트릭을 안 띄우므로 화면 영향 없음 |
| 기록 홀 0개 | 전송하지 않고 스냅샷만 삭제. 버튼 `저장 없이 종료` |
| 전송 없이 요약 이탈 | 스냅샷 유지 → 다음 실행 때 복구 |
| 스냅샷 있는데 새 라운드 시작 | 확인 다이얼로그 (§3.6) |
| 구버전 스냅샷 디코딩 | `id` 새로 생성 · `holeCount`는 `max(18, holeScores.count)` (§3.5) |
| 상한 없던 시절 스냅샷이 18홀을 넘김 | 위 하한 덕에 기록이 잘리지 않는다. 그 라운드는 이후로도 늘릴 수 없다(현재 인덱스가 이미 상한) |
| 복구된 라운드의 홀 수 | 스냅샷의 `holeCount`. 홈 선택값 무시 |
| 전송 후 스냅샷 삭제 전 크래시 | 복구 후 재전송 → iOS가 같은 `id`로 중복 차단 |

## 9. 파일 배치

```
Shared/Models/RoundSnapshot.swift            수정  +id +holeCount +trimmed() +init(from:)
Shared/Models/RoundMetrics.swift             신규  Foundation만
Shared/Services/ConnectivityMessages.swift   신규  ← pbxproj 예외: Complication 제외

WatchApp/Services/RoundTransmitter.swift             신규  RoundTransmitting 구현
WatchApp/Services/RoundMetrics+WorkoutResult.swift   신규  변환 (워치 전용)

WatchApp/Features/Home/HomeView.swift                      수정  N홀 시작 · 홀 수 행
WatchApp/Features/Home/HomeViewModel.swift                 신규
WatchApp/Features/Home/Components/HoleCountSelector.swift  신규  라벨 + 값 버튼

WatchApp/Features/Round/RoundSessionView.swift    수정  ZStack 분기 · 확인 다이얼로그
WatchApp/Features/Round/RoundViewModel.swift      수정  id · .summary · 전송
WatchApp/Features/Round/HoleProgress.swift        수정  holeCount 상한
WatchApp/Features/Round/Summary/SummaryView.swift 신규
```

`Summary/`는 페이지 폴더 규칙(③-c 스펙 §3)을 따라 `Round/` 아래 형제로 들어간다.

## 10. 테스트

View는 테스트하지 않는다(프로젝트 규칙).

- **`HoleProgress`** — 마지막 홀에서 `canGoToNextHole`이 거짓 / `advanceToNextHole()`이 상한을 넘지 않음 / 9홀·18홀 각각. 기존 17건은 `init(holeCount:)`로 치환
- **`RoundSnapshot`** — `trimmed()`: 말단 미기록 제거 / 중간 `par == 0` 보존 / 전부 미기록이면 빈 배열 / 인덱스 클램프. 하위호환 디코딩: `id`·`holeCount` 없는 구버전 dict가 복원됨 / 18홀을 넘긴 구버전 스냅샷이 잘리지 않음
- **`RoundViewModel`** — `finishRound()`가 `.summary`로 전환 / 전송 호출 / 0홀이면 전송 안 함 / `metrics`가 nil이면 0으로 전송 / 전송 후 스냅샷 삭제
- **`HomeViewModel`** — 스냅샷 있으면 복구 / 없으면 유지 / 두 번째 호출은 무시

## 11. 범위 밖

- **iOS 수신·저장·기록 화면** (plan ⑤) — 이 설계는 발신까지다. 받는 쪽은 아직 없다
- **로컬라이즈** (plan ⑦) — 이 화면들도 한국어 하드코딩
- **MapKit 골프장 감지** (plan ⑧) — `courseName`은 이 설계 내내 `nil`
- **"라운드 준비" 화면 승격** — ⑧에서 골프장 입력과 함께 (§3.4)
- **워치의 완료 라운드 로컬 보관** — 리빌드 스펙 §14에서 명시적 제외
- **전반/후반 이어치기** — 홀 수 고정의 대가. 9홀을 골라 끝낸 뒤 더 치려면 새 라운드이고 iOS에는 라운드 2개로 기록된다
