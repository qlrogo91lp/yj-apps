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
