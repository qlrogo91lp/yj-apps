# 동기화/세션 라이프사이클 신뢰성 — 라운드 2 설계

## 작업일: 2026-06-28

> 상태: **설계 (구현 미착수).** 실기기 테스트에서 재발견된 4가지 증상을 분석해 설계로 정리했다.
> 2026-06-24 sync authority 재설계(PR #4~#7)로 양방향 echo·authority·sessionId 가드를
> 구조적으로 해결했으나, 그 위에 남은 **라이프사이클(LiveActivity·workoutEnd) 신뢰성**과
> **미러 UI·점수 동기화 검증** 문제를 이번 라운드에서 다룬다.
>
> **선행 분석:** `docs/superpowers/logs/2026-06-24-bidirectional-sync-root-cause-analysis.md`

## 배경 — 실사용 보고 (2대 실기기)

스크린샷에서 **Live Activity가 3개 쌓여** 있었고, iOS↔워치를 왕복하며 다음이 관찰됐다.

**상황 1 — 워치 먼저 시작 → iOS 진입 (워치=driver, iOS=mirror)**
- 세트 점수는 동기화됨. "보기 전용" 안내도 정상 표시.
- **현재 게임 점수(15/30/40)는 iOS 미러에 동기화 안 됨** (세트만 맞고 포인트는 0에 멈춤).
- **워치에서 운동 종료 시 iOS가 종료되지 않음.** 이때부터 꼬여서 프로세스/Live Activity가 누적.

**상황 2 — iOS 먼저 시작 (iOS=driver, 워치=mirror)**
- 워치 미러엔 게임 점수가 잘 동기화됨.
- "보기 전용" 표기가 **하단(undo 자리)** 에 오는 게 좋겠음 (미러는 undo가 안 떠서 그 공간이 빔).
- 역시 **워치에서 종료하면 꼬임.** Live Activity가 계속 떠 있음.

추가 확인 요청: 운동 경과시간이 양 기기에서 제대로 동기화되는지.

---

## 근본 원인 분석 (systematic-debugging Phase 1)

### A. Live Activity 좀비 누적 — **확정**

`LiveActivityService.start()`가 새 액티비티를 요청하기 전에 **기존 `self.activity`를 end 하지 않고
덮어쓴다** (`iOSApp/Services/LiveActivityService.swift:19`). 이전 액티비티 참조를 잃어 `end()`로도
죽일 수 없는 좀비가 된다. 게다가 `start()`가 중복 호출된다:

- `WorkoutSessionViewModel.handleIncomingSessionStart`가 `start()`를 **두 번** 호출 —
  `startMatch()` 내부(`:167`) + 직후 직접 호출(`:237`).
- iOS 진입 경로가 둘: `WorkoutSessionView.onAppear(remoteSession)`의 `startMatch`(`:97-99`)와
  VM의 `$receivedSessionStart` → `handleIncomingSessionStart` 바인딩(`:84-88`)이 모두 매치를 시작할 수 있다.

→ 워치 driver일 때 iOS 미러가 세션 시작마다 좀비를 1개+ 누수. 왕복하며 3개로 쌓인 것이 스크린샷의 정체.
워치 종료가 iOS에 전달 안 되는 문제(원인 B)와 합쳐져 좀비가 영구 잔존한다.

### B. workoutEnd 전달 비신뢰 — **확정**

`sendWorkoutEnd`가 `sendRealtimeOnly`를 쓴다 (`Shared/Services/WatchConnectivityService.swift:272`).
이 경로는 **`isReachable`일 때만 전송하고, 아니면 그냥 버린다** (`transferUserInfo` 큐잉 없음,
`:279-286`). 워치 종료 순간 아이폰이 백그라운드/화면꺼짐이면 종료 신호가 증발 → iOS 세션·Live
Activity가 살아남는다. step2에서 scoreState·matchEnd는 `sendReliably`로 전환했으나 **workoutEnd만 누락**됐다.

종료 자체는 이미 **양방향 설계**다: iOS `endSession`→워치 `handleIncomingWorkoutEnd`→`endWorkout`,
워치 `endWorkout`→iOS `handleIncomingWorkoutEnd`→`endSession`. 망가진 것은 **워치→iOS 방향의 전달
신뢰성**뿐이다.

### C. 미러 배지 위치 — **요청 사항**

`MirrorBadge`가 상단에 표시된다 (iOS `Features/Match/Score/ScoreView.swift:67-72`,
워치 `:34-39`). 미러 기기는 undo 버튼이 표시되지 않으므로(`lastAction == .none`), 그 **하단 공간**으로
배지를 옮긴다. undo(driver)와 배지(mirror)는 상호배타라 자리를 공유한다.

### D. 인게임 점수 동기화(워치 driver → iOS 미러) — **코드상 정상, 실기기 계측 필요**

워치 driver의 `addPoint`는 매 포인트 `onStateChanged?()`로 전체 스냅샷을 전송하고
(`WatchApp/.../ScoreViewModel.swift:38`), iOS 미러의 수신→`applyRemoteState`→표시 경로도 코드상
정상이다. "세트는 되는데 현재 게임 점수만 0에 멈춤"이 재현되려면 **실제로 어떤 메시지가 iOS에
도착하고 그 값이 무엇인지**를 봐야 한다. 코드 리딩만으로 단정하면 이 영역의 5번째 "절반 수정"이
될 위험이 크다 ([[watch-sync-simulator-trap]]). 참고로 `score_deciding_point`("매치 포인트") 문자열은
현재 **어디에도 사용되지 않는 dead string**이며, 보고된 "매치 포인트"는 인게임 점수(15/30/40)를 가리킨다.

가능한 끊김 지점은 셋이며 화면상 증상이 전부 동일("0-0 멈춤")하다:
1. 워치가 인게임 점수를 애초에 전송 안 함
2. 워치는 보냈으나 iOS가 미수신(미도달 드롭/큐잉 지연)
3. iOS가 수신했으나 적용/표시 실패(0으로 덮임 등)

→ 송·수신 경계 계측으로 1·2·3 중 어디인지 확정한 뒤 고친다.

### E. 운동 경과시간 드리프트 — **2차/검증**

iOS는 `startedAt` 기준 자체 타이머로 elapsed를 계산하며(`WorkoutSessionViewModel.swift:312-327`)
워치의 pause를 모른다. 일시정지 시 양 기기 경과시간이 어긋날 수 있다.

---

## 정해진 방향 (사용자 결정)

| # | 결정 | 선택 |
|---|------|------|
| 1 | 작업 범위 | 단일 스펙 + 다단계 plan (이전 PR #4~#7 패턴) |
| 2 | 인게임 점수 버그 | 진단 우선 — 블라인드 수정 금지 |
| 3 | 진단 로깅 | OSLog 양쪽 + `privacy: .public`, Console.app 교차 확인 (인앱 로그 뷰 불필요, 케이블 사용) |
| 4 | 진단 빌드 | 섹션 1~3 수정 + 로그를 **한 TestFlight 빌드**에 실어 1회 검증 |
| 5 | 운동 종료 | 양방향 종료 + 전달 신뢰성 보장 |

---

## 설계

### 단계 1 — Live Activity 라이프사이클 (원인 A)

- `LiveActivityService.start(mode:)`를 **멱등**으로 만든다:
  - 새 `Activity.request` 전에 기존 `self.activity`를 end.
  - 앱/서비스 차원의 고아 정리: `Activity<TennisActivityAttributes>.activities`를 순회해 잔존분 end
    (크래시·강제종료로 남은 것 포함). 시작 시 1회 청소.
- iOS `WorkoutSessionViewModel.handleIncomingSessionStart`의 **중복 `start()` 호출(`:237`) 제거** —
  `startMatch`가 이미 시작한다.
- iOS 매치 진입 경로 단일화: `WorkoutSessionView.onAppear(remoteSession)`와
  `handleIncomingSessionStart` 바인딩이 **이중 startMatch** 하지 않도록 한 곳만 책임지게 한다.
  (onAppear는 최초 진입, 바인딩은 진입 후 도착분 — 이미 `.playing`+`!isDriver`면 재시작 안 하도록
  가드가 있으나, 최초 진입의 이중 실행 경로를 명시적으로 정리.)

**테스트:** ActivityKit은 유닛테스트 불가. VM 레벨에서 "원격 세션 시작 → 매치 시작 경로가 1회만
실행"을 검증(예: 시작 카운터/스파이). LiveActivityService 멱등성은 실기기 확인.

### 단계 2 — workoutEnd 신뢰성 + 양방향 종료 (원인 B)

- `WatchConnectivityService.sendWorkoutEnd`를 `sendRealtimeOnly` → **`sendReliably`**로 전환
  (미도달 시 `transferUserInfo` 큐잉).
- **안전성 근거:** 늦게 도착한 stale 종료는 수신측 `sessionId` 가드(`hasSyncedSession, id !=
  activeSessionId → return`)가 무시한다. 따라서 reliable 전환이 안전하다.
- **엣지 케이스:** `hasSyncedSession == false`일 때 가드가 모든 workoutEnd를 수용하는 폴백이 있다
  (PR #6에서 "매치 미시작 시 가드가 전부 차단" 회귀를 막으려 추가). reliable 전환으로 큐잉된 stale
  종료가 새 실행 초기(매치 시작 전)에 도착하면 잘못 종료시킬 수 있다. 발생 확률은 낮으나, 이 단계에서
  **소비 즉시 nil(이미 적용됨) + sessionId 일치 우선** 동작을 테스트로 고정하고, 폴백 수용 범위를
  재검토한다.
- 양방향은 이미 설계되어 있으므로 추가 구조 변경 없이 신뢰성만 확보된다.

**테스트:** (a) 일치 sessionId 종료 수용→세션 종료, (b) 불일치 stale 종료 무시, (c) 미도달 시
`transferUserInfo` 경로 사용, (d) 종료 신호 소비 후 즉시 nil. iOS·워치 양쪽 VM/Service 단위.

### 단계 3 — 미러 UI: 보기전용 배지 하단 이동 (원인 C)

- iOS/워치 `ScoreView`에서 `MirrorBadge`를 상단 → **undo 버튼이 있던 하단 위치**로 이동.
- driver는 하단에 undo, mirror는 하단에 배지 — 상호배타로 같은 자리 사용.

**테스트:** UI → 수동 확인.

### 단계 4 — 인게임 점수 동기화 진단 계측 (원인 D)

- `import OSLog`, subsystem `com.yj.TennisCounter.sync`, category `score`.
- 모든 동적 값에 `privacy: .public` (TestFlight = 릴리스 빌드라 미지정 시 `<private>` 가림).
- **워치 송신** (`WatchConnectivityService.sendScoreState` 또는 호출부):
  `sent my=.. your=.. sets=.. tieBreak=.. reachable=..`
- **iOS 수신** (`WorkoutSessionViewModel.handleIncomingScoreState`):
  `recv my=.. your=.. sets=.. isDriver=.. phase=..`
- 단계 1~3 수정과 **한 진단 빌드**로 TestFlight 1회 업로드.
- 재현 절차: 워치에서 게임을 끝내지 않는 점수 1개(15)만 입력 → iOS 화면 확인.
  - iOS가 즉시 15로 따라오면 → **버그 없음** (이전 빌드 잔재/step2로 해소). 로그 제거하고 종결.
  - 0에 멈추면 → Console.app에서 워치 `sent my=15` / iOS `recv my=?` 비교해 끊김 지점(1·2·3) 확정.
- **실제 수정은 진단 결과에 따른 후속 작업**으로 진행한다. 이 단계의 산출물은 "계측 + 재현 + 원인
  확정"까지이며, 원인 확정 후 로그를 제거한다.

### 운동 경과시간 (원인 E) — 2차 검증

단계 4 진단 빌드로 elapsed 동기화를 함께 관찰한다. 드리프트가 재현되면 미러 측 iOS가 워치
`metrics.elapsedSeconds`를 신뢰하도록 정렬하는 후속 수정을 검토한다(이번 스펙 범위 밖, 재현 시 추가).

---

## 범위 밖 (Non-goals)

- 인게임 점수 버그의 **블라인드 수정** — 진단으로 원인 확정 후 별도 진행.
- 운동 경과시간 드리프트의 선제 수정 — 재현 확인 후.
- `upsert` 실패 시 컨텍스트 stuck (별도 스펙 `2026-06-25-upsert-failure-handling-design.md`).
- 동기화 authority 구조 자체 (이미 PR #4~#7로 완료).

## 검증 (전체 공통)

- 빌드/유닛테스트 GREEN.
- **실기기 2대 수동 확인 필수** — 이 영역은 시뮬레이터로 재현되지 않는다([[watch-sync-simulator-trap]]).
  진단 빌드(단계 1~4)로: ① Live Activity가 1개만 뜨고 종료 시 사라짐, ② 워치 종료 시 iOS도 종료,
  ③ 보기전용 배지 하단 표시, ④ 인게임 점수 동기화 송·수신 로그 교차 확인.

## 구현 순서

각 단계 독립 PR · TDD · `/code-review` 게이트. 단계 1·2는 신뢰성 핵심이라 우선. 단계 3은 독립적.
단계 4(계측)는 단계 1~3과 한 빌드로 묶어 검증.
