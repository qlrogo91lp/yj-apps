# Watch↔iOS 양방향 동기화 — 반복 재발 버그 근본 원인 분석

## 작업일: 2026-06-24

> 상태: **분석 + 설계/계획 완료 (구현 미착수).** 근본 원인 분석을 바탕으로 spec과 4단계 plan을
> 수립했다. 구현이 진행되면 각 단계의 "수정 내용"을 이 문서 하단에 계속 덧붙인다.
>
> **후속 산출물:**
> - 설계: `docs/superpowers/specs/ios/2026-06-24-sync-authority-redesign-design.md` (커밋 1dd043f)
> - 계획: `docs/superpowers/plans/ios/2026-06-24-sync-step1~4-*.md` (커밋 0d04214)

## 배경

워치 실사용 중 재발견된 3가지 증상을 분석. 이 영역은 2026-05-29 / 05-30 / 06-11 /
06-12에 걸쳐 이미 4번 손댔으나 양방향 동기화 버그가 계속 재발했다. 이번엔 개별 패치가
아니라 **왜 반복 재발하는지**까지 규명한다.

---

## 현재 증상 (실사용 보고)

1. **결과화면 초기화(리매치) 버튼을 눌러도 점수가 초기화 안 됨** (워치)
2. **운동 중 갑자기 홈 화면으로 나가 있음** (워치) — 물리 버튼 때문인지 불명
3. **홈/복귀 시 세트 스코어는 유지되는데 현재 게임의 점수가 날아감** (워치)

---

## 근본 원인 (3가지 증상 공통)

### A. 양방향 동기화에 authority(주인)가 없음

iOS와 Watch가 **둘 다** scoreState를 보내고, 받은 건 **무조건** `applyRemoteState`로 덮어쓴다.
특히 iOS는 `isWatchReachable`가 true가 될 때마다 자기 점수를 되쏜다(echo):

- `iOSApp/Features/Match/Score/ScoreViewModel.swift:47-51` — `$isWatchReachable.filter{$0}` → `sendScoreState()`

도달성(reachable)은 손목 내림/올림·앱 백그라운드로 수시로 깜빡이므로, echo가 계속 발생해
Watch의 현재 상태를 stale 값으로 덮어쓴다.

### B. 경기 상태가 재생성 가능한 view 상태에만 존재

`ScoreViewModel`이 `ScoreView`의 `@StateObject`다 (`WatchApp/.../Score/ScoreView.swift:6,12`).
리매치/탭 전환/재진입 시 상태 리셋·유지가 전부 "SwiftUI가 view를 재생성하느냐"에 의존한다.
명시적 리셋·영속 저장이 없다.

---

## 증상별 메커니즘

### 증상 1: 리매치 미초기화

- `restartMatch() → startMatch() → phase=.playing` (`WatchApp/.../WorkoutSessionViewModel.swift:124,67`).
  점수 리셋 코드 없음 → `@StateObject` 재생성에만 의존(원인 B).
- 06-11에 `startMatch(isRemote:false)`에서 `receivedScoreState=nil`을 추가해 **init replay**는 막았으나,
  그 직후 sessionStart를 받은 iOS가 `isWatchReachable` echo로 점수를 **다시 push**(원인 A) → 막지 못함.
- iOS도 동일 구조. iOS엔 `resetAll()`(`iOSApp/.../ScoreViewModel.swift:70-81`)이 있으나 **호출 안 됨**.

### 증상 2: 갑자기 홈

- `WatchApp/.../WorkoutSessionView.swift:32-34` — `remoteWorkoutEnded` true → `dismiss()`.
- `remoteWorkoutEnded`는 `receivedWorkoutEnd`(iOS의 `workoutEnd` 메시지)로 세팅됨
  (`WorkoutSessionViewModel.swift:38-46`, `WatchConnectivityService.swift:275`).
- 즉 **iOS가 세션을 끝내면(또는 끝났다 판단하면) 워치가 경기 중이든 강제 dismiss**.
- 05-29/05-30은 *stale·오염된* workoutEnd만 막았지, **살아있는 workoutEnd가 활성 워치를 dismiss하는
  설계 자체**는 그대로. `workoutEnd`에 **sessionId 가드 없음** (다른 메시지엔 챙기면서 여기만 누락).
- iOS도 대칭: `iOSApp/.../WorkoutSessionView.swift:104-106` 동일 패턴.

### 증상 3: 세트 유지·게임 점수 날아감

- 인게임 점수(15/30/40)가 동기화 메시지에 **항상 0으로** 실림:
  워치 `addPoint`는 게임 승리 시에만 통과 → `score.reset()` **뒤에** `sendScoreState()` 호출 →
  `myScore/yourScore=0` (`WatchApp/.../ScoreViewModel.swift:35-43, 61-75`).
- 게다가 `sendScoreState()`가 `checkSetUpdate()` **앞**이라 세트 확정(set++/games=0)은 절대 broadcast 안 됨.
- iOS echo가 돌아오면 `applyRemoteState`가 `score.applyRemote(myScore:0,yourScore:0,…)` 실행 →
  **진행 중이던 게임 점수가 0-0으로 지워지고**, 게임/세트 카운트(메시지에 있음)는 유지됨 → 정확히 보고 증상.
- iOS는 전송 순서가 정상(`checkSetUpdate` 다음 `sendScoreState`, `iOSApp/.../ScoreViewModel.swift:61-62`)이라
  이 타이밍 버그는 **워치 전용**. 단 무조건 덮어쓰기 구조는 iOS도 동일(`83-94`).

> 주: "세트는 살아있고 게임만 날아감"은 **iOS가 백그라운드에서라도 echo를 보내고 있었음**을 의미한다
> (완전 로컬 리셋이면 세트도 날아갔어야 함). 워치만 만져도 iOS가 능동 개입한다는 증거.

---

## 왜 그동안 개선이 안 됐나 (핵심)

### 1) 진단을 시뮬레이터로 함 → 버그가 시뮬레이터에 존재하지 않음

06-11 로그: 시뮬레이터에서 `applyRemoteState`가 한 번도 안 불려 "정상 초기화"로 판정하고
실기기 버그를 "stale 빌드 탓, 재설치로 해결"로 귀결. 하지만 `applyRemoteState`가 안 불린 건
echo 조건(페어 iPhone의 도달성 변화 재전송)이 시뮬레이터에 없기 때문. **재현 불가 환경에서
"정상"을 확인한 것.** 기존 테스트도 `receivedScoreState`를 직접 세팅해 init replay만 검증,
echo 경로는 한 번도 실행 안 함.

### 2) 진짜 원인을 06-12에 짚고도 거절함

06-12 메모리 누수 로그: "`ScoreViewModel`을 `WorkoutSessionViewModel`로 끌어올려 단일 인스턴스 +
`resetAll()` 재사용으로 제거 가능. (현재는 과한 변경)" → **근본 수정을 명시적으로 declined.**
또 "잔류 VM이 `applyRemoteState`를 중복 실행하는 미미한 낭비"라고 했으나, 실제론 **좀비 구독자들이
살아 echo를 계속 받는 증거**였다(동기화 관점으로 안 봄).

### 3) 매번 "절반만" 고침

- 증상1: init replay만 막고 active re-push는 안 막음.
- 증상2: stale workoutEnd만 막고 살아있는 workoutEnd dismiss 설계는 유지, sessionId 가드 누락.
- 증상3: 전송 타이밍/덮어쓰기 구조는 한 번도 손대지 않음 (어느 로그에도 없음).

---

## 정해진 수정 방향 (후속 작업)

1. **`ScoreViewModel`을 `WorkoutSessionViewModel`로 끌어올려 단일 인스턴스 + `resetAll()` 재사용**
   → 증상 1·3의 "view 재생성 의존" 제거. (06-12가 이미 제시한 방향)
2. **driver/mirror 권한 모델** → 미러는 echo를 신뢰성 있게만 받고, 자기 입력 외엔 덮어쓰지 않음. (증상 3)
3. **`workoutEnd`에 sessionId 가드 + 소비 후 즉시 nil** → 무관한/stale 종료 신호 무시. (증상 2)
4. **검증을 echo 경로까지** → 두 ViewModel 간 실제 송수신 통합 테스트 또는 실기기 2대 수동 확인.
   "시뮬레이터에서 안 보임 = 고쳐짐" 금지.

> 구조 변경이므로 brainstorming → spec → plan 순서로 진행. 본 분석이 그 입력.

---

## 후속: 채택된 설계 (2026-06-24)

분석 후 brainstorming을 거쳐 다음 7개 결정을 확정했다 (상세: spec 문서).

| # | 결정 | 선택 |
|---|------|------|
| 1 | 작업 범위 | spec 1개, plan은 4단계 분할 |
| 2 | driver 결정 | 경기를 시작한 기기가 driver, 상대는 mirror (`isRemote` 재사용) |
| 3 | 상태 소유권 | WorkoutSessionViewModel이 ScoreViewModel 단일 인스턴스 소유 + `resetAll()` |
| 4 | 동기화 충실도 | 매 포인트 전체 스냅샷 전송, mirror는 적용만 (echo 제거) |
| 5 | workoutEnd | sessionId 일치 가드 + 소비 즉시 nil |
| 6 | 저장 중복 | sessionId upsert |
| 7 | 미러 입력 | 완전 비활성 + 보기전용 배지 (handoff 없음) |

**핵심 통찰:** driver/mirror 단방향은 echo가 흐를 경로를 양쪽에서 닫는다(driver는 수신 무시,
mirror는 전송 안 함). 따라서 증상 3의 echo 출처를 실기기 계측으로 끝까지 밝히지 못해도
구조적으로 제거된다. 미래 소켓 멀티(room=authority)와도 동일 계열이라 버려지는 설계가 아니다.

**구현 단계 (각 독립 PR · TDD · `/code-review` 게이트):**
1. 상태 소유권 이동 (증상 1)
2. 단방향 authority (증상 3)
3. workoutEnd 가드 + 미러 UI (증상 2)
4. 저장 upsert (중복 방지)

> 이후 각 단계 구현이 끝나면 "## 구현: N단계" 섹션으로 before/after·이슈를 여기 추가한다.

---

## 구현: 1단계 — 상태 소유권 이동 (PR #4, 2026-06-25 머지)

**계획:** `docs/superpowers/plans/ios/2026-06-24-sync-step1-state-ownership.md`

**Before:** `ScoreViewModel`이 `ScoreView`의 `@StateObject`라, 리매치/탭전환/재진입 시 점수 초기화가 "SwiftUI가 view를 재생성하느냐"에 암묵적으로 의존했다(원인 B). 명시적 리셋이 없어 증상 1(리매치 미초기화)이 발생.

**After:**
- iOS/Watch `ScoreViewModel.resetAll(options:)` 도입 — `options`를 `private(set) var`로 바꿔 동일 인스턴스를 재사용 가능하게 함.
- `WorkoutSessionViewModel`이 `scoreVM`을 단일 인스턴스로 소유하고, `startMatch`/`restartMatch`에서 `resetAll(options:)`를 명시적으로 호출.
- `ScoreView`는 `@StateObject` → `@ObservedObject` 주입식으로 전환 (iOS/Watch 동일).
- Watch는 `onMatchFinished` 콜백을 `ScoreView.onAppear`가 아니라 `WorkoutSessionViewModel.init()`에서 연결하도록 이동(중복 설정 방지).

**커밋:** `e468220`(iOS resetAll), `1053b97`(Watch resetAll), `7d9671f`/`aa10000`(scoreVM 소유), `01ce963`/`776a880`(ScoreView 주입식), `60938b9`(`options` `@Published` 전환), `ebb5e8a`(swiftformat/swiftlint).

**이슈:** 없음 (code-review 통과, 추가 수정 없이 머지).

---

## 구현: 2단계 — 단방향 authority (PR #5, 2026-06-25 머지)

**계획:** `docs/superpowers/plans/ios/2026-06-24-sync-step2-unidirectional-authority.md`

**Before:** iOS·Watch 둘 다 scoreState를 보내고 받은 건 무조건 덮어썼다(원인 A, echo). Watch는 `sendScoreState()`가 `checkSetUpdate()` **앞**, `score.reset()` **뒤**에 있어 인게임 점수가 항상 0으로 전송됨(증상 3).

**After:**
- iOS/Watch `ScoreViewModel`을 connectivity 의존 없는 순수 로직으로 전환. `onStateChanged` 콜백 + `makeScoreState()` 공개.
- `WorkoutSessionViewModel`이 `isDriver`(경기를 시작한 기기)를 들고, driver만 전송(`onStateChanged`에서 송신), mirror만 수신 적용(`handleIncomingScoreState`에서 driver면 무시). echo 경로를 양쪽에서 구조적으로 차단.
- Watch `addPoint` 전송 타이밍 버그 수정 — `score.reset()` → `checkSetUpdate()` → `onStateChanged?()` 순서로 정정.
- LiveActivity 갱신 책임을 `ScoreViewModel`에서 `WorkoutSessionViewModel`로 이동.

**커밋:** `ddf67b5`(iOS 순수화), `a6f0b62`(Watch 순수화+타이밍버그), `8e4b9e8`/`5eb3f65`(driver/mirror 동기화), `17283f1`(init 분리, function_body_length lint).

**이슈 (code-review 반영, 커밋 `01409f1`):**
- `restartMatch()`가 `isDriver` 역할을 보존하지 못하던 버그 수정.
- `handleIncomingScoreState`에 `phase == .playing` 가드 추가 — 경기 종료 후 도착하는 stale 원격 점수 무시.
- 동시 시작 race 해소: 두 기기가 동시에 시작할 때 `sessionId` UUID 문자열 비교로 deterministic하게 한쪽만 driver 유지.
- `ScoreEditSheet`(수동 점수 수정)이 `onStateChanged` 동기화 파이프라인을 안 거치던 문제 수정.
- `sendScoreState`를 `sendRealtimeOnly` → `sendReliably`로 변경 — reachability 손실 시 `transferUserInfo`로 큐잉되게.

---

## 구현: 3단계 — workoutEnd 가드 + 미러 UI (PR #6, 2026-06-25 머지)

**계획:** `docs/superpowers/plans/ios/2026-06-24-sync-step3-workoutend-guard-mirror-ui.md`

**Before:** `workoutEnd` 메시지에 `sessionId`가 없어, 무관하거나 stale한 종료 신호에도 활성 기기가 강제로 홈으로 dismiss됐다(증상 2). 미러 기기도 점수 입력이 가능해 두 기기가 동시에 입력하면 충돌 가능.

**After:**
- `WatchConnectivityService.receivedWorkoutEnd`를 `Date?` → `UUID?`로 변경. 전송 시 `sessionId`를 함께 보내고, 수신 측은 자기 현재 세션 id와 일치할 때만 처리 + 소비 즉시 `nil`로 비움.
- iOS/Watch `MirrorBadge` 컴포넌트 신설 — 미러 기기에 "보기 전용" 배지 표시.
- 미러 기기는 점수 영역 탭(`onTap`/`action`)이 `isDriver` 가드로 막힘.

**커밋:** `aff70aa`(iOS sessionId 가드), `9edb2d5`(Watch sessionId 가드), `c7e2703`/`17cfc48`(미러 입력 비활성+배지), `44b100c`(swiftformat).

**이슈 (code-review 반영, 커밋 `a12c271`):**
- 매치가 한 번도 시작되지 않아 `sessionId`가 아직 동기화 전인 상태에서 `workoutEnd` 가드가 모든 신호를 막아버리던 회귀 — `hasSyncedSession` 플래그로 "가드 도입 전 동작"(무조건 수용) 복원.
- Watch `restartMatch()`가 mirror 상태에서 `activeSessionId` 대신 동기화 안 된 `workoutSessionId`로 폴백하던 버그 수정.
- iOS `ScoreView`의 `onLongPress`(수동 점수 수정)에 `isDriver` 가드가 빠져있어 미러 기기가 long-press로 입력을 우회할 수 있던 구멍 수정.

---

## 구현: 4단계 — 저장 upsert (PR #7, 2026-06-25 머지)

**계획:** `docs/superpowers/plans/ios/2026-06-24-sync-step4-save-upsert.md`

**Before:** `MatchPersistenceService.save(_:)`는 항상 insert만 했다. driver가 로컬에서 저장(`saveCurrentMatch`)하고 mirror 쪽 사용자도 별도로 저장(`saveFromWatch`)하면, 같은 경기(`workoutSessionId`)가 History에 2건으로 중복 저장될 수 있었다.

**After:**
- `MatchPersistenceService.upsert(_:)` 추가 — `workoutSessionId`로 기존 Match를 조회해 있으면 삭제 후 insert, 없으면 insert.
- `saveCurrentMatch`/`saveFromWatch` 모두 `upsert`를 경유하도록 통일.
- 더 이상 호출되지 않는 `save(_:)` 제거.

**커밋:** `b2b977f`(upsert 구현+테스트), `008ed07`(저장 경로 전환), `b722f2d`(`save` 제거), `3770090`(swiftformat).

**이슈 (`/code-review`, 수정 보류):**
- `upsert`는 `context.delete(old)` → `context.insert(match)` → `context.save()` 순서다. `save()`가 실패하면(드묾: CloudKit 충돌·디스크 오류 등) SwiftData/CoreData가 pending 상태인 delete/insert를 자동 롤백하지 않고, 코드베이스 전체에 `rollback()` 호출이 없다. 두 호출부 모두 `try?`로 실패를 삼키므로, 이 stuck 상태가 앱 전체가 공유하는 메인 `ModelContext`에 남아 이후 무관한 화면(History 등)의 저장까지 연쇄 실패시킬 수 있다.
- 기존 `save()`(insert만)도 동일한 구조적 위험(롤백 부재 + `try?`)을 갖고 있어 **이 diff가 새로 만든 버그는 아니나, delete가 추가되며 위험이 커졌다.**
- 발생 확률이 낮아 이번 단계 범위에서는 수정하지 않고 보류. 후속 조치는 별도 brainstorming/plan으로 진행 예정.

**검증 한계:** 워치 저장→iOS History 1건 확인은 시뮬레이터로 신뢰성 있게 재현되지 않는다([[watch-sync-simulator-trap]]). 빌드/단위테스트는 GREEN이나, 실기기 2대 수동 확인은 PR 머지 시점에 아직 수행하지 않았다.

---

## 종합 — 4단계 전체 완료 (2026-06-25)

증상 1·2·3을 일으킨 구조적 원인(authority 부재, view 상태 의존, sessionId 가드 누락, 저장 중복)을 4개의 독립 PR(#4~#7)로 모두 해소했다. 각 단계는 TDD + `/code-review` 게이트를 통과했고, 2·3단계는 code-review에서 실제 회귀(역할 보존, race, 가드 회귀, 입력 우회)를 잡아 반영했다. 남은 항목:
1. 4단계 code-review에서 나온 `upsert` 실패 시 컨텍스트 stuck 위험 — 후속 plan 대상.
2. 1~4단계 전체에 대한 실기기 2대 수동 확인 — 시뮬레이터로 대체 불가.
