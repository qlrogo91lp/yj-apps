# Watch↔iOS 점수 동기화 — authority 기반 재설계

## 작성일: 2026-06-24

## 배경

Watch↔iOS 양방향 점수 동기화 버그가 2026-05~06에 4번 수정됐는데도 계속 재발했다
(상세: `docs/superpowers/logs/2026-06-24-bidirectional-sync-root-cause-analysis.md`).
근본 원인은 두 가지 구조적 문제다:

1. **양방향에 authority(주인/소스 오브 트루스)가 없음** — iOS·Watch 둘 다 점수를 보내고,
   받은 건 무조건 `applyRemoteState`로 덮어쓴다. iOS는 `isWatchReachable`가 true가 될 때마다
   자기 점수를 되쏘는데(echo), 도달성이 손목 내림/올림으로 수시로 깜빡여 Watch의 현재 상태가
   stale echo에 덮어써진다.
2. **경기 상태가 재생성 가능한 view 상태에만 존재** — `ScoreViewModel`이 `ScoreView`의
   `@StateObject`라서 리매치/탭전환/재진입 시 상태 유지·리셋이 "view 재생성"에만 의존한다.

이 설계는 개별 증상 패치가 아니라 위 두 뿌리를 구조적으로 제거한다.

### 실사용 증상 (이 설계가 해결할 대상)

1. 결과화면 초기화(리매치) 버튼을 눌러도 점수가 초기화 안 됨
2. 운동 중 갑자기 홈 화면으로 나가 있음
3. 홈/복귀 시 세트 스코어는 유지되는데 현재 게임의 점수가 날아감

### 실사용에서의 가시성 (워치 단독 관찰)

워치 단독 실사용에서 **빈번히 관찰된 것은 증상 3뿐**이다. 증상 1·2는 이전 수정
(05-29/05-30/06-11)으로 코드 레벨에서 대부분 완화돼 거의 보이지 않았다.

| 증상 | 이전 수정 | 현재 잔존 | 워치 단독 가시성 |
|------|----------|----------|-----------------|
| 1 리매치 미초기화 | 06-11 `receivedScoreState=nil` + @StateObject 재생성 | echo 재오염 엣지만 | 드묾(대체로 정상) |
| 2 갑자기 홈 | 05-29/05-30 stale workoutEnd 제거 | 살아있는 workoutEnd 오신호 엣지 | 드묾(트리거 불명확) |
| 3 게임 점수 날아감 | **없음** | 그대로 | **빈번(주증상)** |

증상 3의 정확한 echo 출처(iOS 앱이 백그라운드에서 `isReachable`이 되는 시점/경로)는 실기기 계측
없이 100% 확정이 어렵다. 그러나 본 설계의 driver/mirror 단방향은 **양쪽에서 데이터 흐름을 닫는다**:
driver(입력 기기)는 수신 스냅샷을 **적용하지 않고**, mirror(보조 기기)는 **아예 전송하지 않는다**.
echo가 새어나올 코드 경로가 양쪽에서 사라지므로, 출처를 끝까지 밝히지 못해도 증상 3은
**구조적으로** 제거된다(특정 경로를 가드하던 기존 방식과 달리 역류 경로 자체가 없음). 통합 테스트 +
실기기 2대 확인으로 잔존 엣지(1·2 포함)까지 검증한다.

---

## 목표 / 비목표

### 목표
- 한 경기에 입력 주체(authority)가 항상 하나임을 보장해 echo 충돌을 원천 제거
- 경기 상태를 view 수명과 분리해 리매치/탭전환/재진입에도 보존
- 인게임 점수(15/30/40)를 미러·Live Activity에 실시간 정확히 반영
- `workoutEnd` 오신호로 인한 의도치 않은 홈 복귀 차단
- 같은 경기가 중복 저장되지 않도록 보장
- echo 경로를 실제로 도는 통합 테스트로 회귀 방지

### 비목표 (YAGNI)
- 두 기기 동시 입력 + 충돌 머지 (분산 합의) — 채택 안 함
- 주도권 넘기기(handoff) — 미래 소켓 작업 때 transport-무관 authority 이전으로 설계
- 소켓 transport 추상화 레이어를 미리 구축 — 지금은 책임만 한곳에 모아 교체 쉽게만
- 경기 상태 영속화(UserDefaults/SwiftData 복원) — driver 모델로 충돌이 사라지면 불필요

---

## 확정된 핵심 결정

| # | 결정 | 선택 |
|---|------|------|
| 1 | 작업 범위 | spec 1개(근본 수정 전체), plan은 단계별 분할 |
| 2 | driver 결정 | **경기를 시작한 기기가 driver, 상대는 mirror** (`isRemote` 플래그 재사용) |
| 3 | 상태 소유권 | **WorkoutSessionViewModel이 ScoreViewModel 단일 인스턴스 소유** + `resetAll()` 재사용 |
| 4 | 동기화 충실도 | **매 포인트 전체 스냅샷 전송**, mirror는 적용만 (echo 제거) |
| 5 | workoutEnd | **sessionId 일치 가드 + 소비 즉시 nil** |
| 6 | 저장 중복 | **sessionId upsert** (어디서 눌러도 1건) |
| 7 | 미러 입력 | **완전 비활성 + 보기전용 배지** (handoff 없음) |

---

## 아키텍처: driver/mirror authority 모델

한 워크아웃 세션 = **driver 하나 + mirror 0~1개**.

- **driver** = 경기를 시작한 기기 (`startMatch(isRemote: false)`). 점수 입력 가능, 상태를 **내보내기만**.
- **mirror** = 원격으로 따라 들어온 기기 (`isRemote: true`). 입력 **비활성**, 상태를 **받아 적용만**.

`WorkoutSessionViewModel`에 `isDriver: Bool` 한 개로 표현한다. 이미 존재하는 `isRemote` 인자에서
파생: driver ⇔ `!isRemote`.

오해 방지: 단방향은 "한 경기에 입력 주체 1개"라는 뜻이지 "iOS는 항상 미러"가 아니다.
- 워치로 시작 → 워치 driver, iOS mirror
- iOS 단독 시작(워치 없음) → iOS driver

### 미래 소켓 멀티와의 호환

driver/mirror는 "한 경기에 authority가 명확히 하나"라는 일반 모델이다. 미래 소켓 room도
"호스트/지정 스코어러가 authority, 나머지는 미러"로 자연 확장된다(room id ≈ `sessionId`).
동기화 방식("authority가 스냅샷 push → 나머지 적용")도 transport(WC/소켓) 무관하게 동일하다.

따라서 **authority 판정과 동기화 송수신 책임을 `WorkoutSessionViewModel` 한 곳에 모으고
transport(WatchConnectivity 호출)와 느슨하게 둔다.** 지금 소켓 추상화를 미리 만들지는 않되,
나중에 `SocketService`를 같은 자리에 끼우기 쉽게 한다.

---

## 상태 소유권 이동

```
[현재]  ScoreView ──@StateObject──> ScoreViewModel   (view가 소유, 재생성 시 소멸)
[변경]  WorkoutSessionViewModel ──owns──> ScoreViewModel (단일 인스턴스)
        ScoreView ──@ObservedObject──> scoreVM         (view는 표시만)
        경기 시작/리매치 → scoreVM.resetAll(options:)   (재사용)
```

### 동기화 책임 분리 (부수 개선)

현재 `ScoreViewModel`이 `WatchConnectivityService`를 직접 구독·전송한다
(CLAUDE.md "ViewModel은 순수 로직" 위반 기미). 이를 `WorkoutSessionViewModel`로 끌어모은다:

- `ScoreViewModel` → **순수 점수 로직만** (connectivity 의존 제거 → 테스트 쉬움)
- `WorkoutSessionViewModel` →
  - driver면 `scoreVM` 상태 변경을 관찰해 스냅샷 전송
  - mirror면 수신 스냅샷을 `scoreVM`에 적용

이로써 증상 1·3의 뿌리(view 재생성 의존 + echo 덮어쓰기)가 사라지고, deinit 누적(메모리 의심)도
단일 인스턴스라 해소된다.

---

## 동기화 프로토콜 (단방향 스냅샷)

### 전송 (driver)
- 점수 변경마다(매 포인트 포함) **올바른 최종 상태**의 전체 `ScoreState` 스냅샷 전송.
- 현재 버그: 워치 `addPoint`가 `score.reset()` **뒤** + `checkSetUpdate()` **앞**에 보내서
  인게임 점수가 항상 0으로 나갔다. → 스냅샷은 **`checkSetUpdate()` 이후, 인게임 점수 포함**한
  실제 현재 상태로 만든다.
- 스냅샷이 유일한 진실. 부분 메시지 없음.

### 수신 (mirror)
- `receivedScoreState`를 받아 `scoreVM`에 적용만 한다.
- **절대 전송하지 않는다** → 기존 iOS `isWatchReachable → sendScoreState` echo 제거.

### 재연결
- driver가 reachable 회복 시 현재 스냅샷을 1회 재전송(기존 `sessionStart` 재전송 자리를
  스냅샷 재전송으로 대체·보강). mirror는 적용.

### workoutEnd 가드 (증상 2)
- `workoutEnd` 메시지에 `sessionId` 포함.
- 수신 측은 **내 현재 세션 sessionId와 일치할 때만** dismiss/endSession.
- 무관/stale 신호는 무시하고, 소비 즉시 `receivedWorkoutEnd = nil` (race·replay 차단).

---

## 미러 UI

- 점수 탭 영역 **입력 비활성** (탭 무반응 + 약간 흐리게 처리해 "여긴 못 누른다"를 시각화).
- **"⌚️ 워치에서 입력 중 · 보기 전용"** 류 배지 표시 (driver 기기 종류에 맞춰 문구).
- driver 기기에는 영향 없음(평소처럼 입력).

---

## 저장 신뢰성

- `MatchPersistenceService`에 `upsert(by workoutSessionId)` 추가:
  같은 `workoutSessionId` Match가 있으면 갱신, 없으면 insert.
- 양쪽 저장 경로(`saveCurrentMatch`, `saveFromWatch`)가 이를 사용 → iOS·워치 어디서 눌러도 1건.
- 오염된 점수 저장은 driver 모델 + 단일 상태 소유로 자동 해결(저장 출처가 깨끗한 `_currentSession`).

---

## 증상 ↔ 해결 매핑

| 증상 | 해결 메커니즘 |
|------|--------------|
| 1. 리매치 미초기화 | 단일 ScoreViewModel + `resetAll()` (view 재생성 의존 제거) + mirror echo 제거 |
| 2. 갑자기 홈 | workoutEnd sessionId 가드 + 소비 즉시 nil |
| 3. 게임 점수 날아감 | 단방향 스냅샷(echo 제거) + 인게임 점수 포함·올바른 전송 타이밍 |
| (잠재) 중복 저장 | sessionId upsert |
| (잠재) 오염 저장 | driver 모델로 ScoreViewModel 오염 제거 → 저장 출처 정상화 |

---

## 테스트 전략 (시뮬레이터 함정 회피)

기존 테스트는 `service.receivedScoreState = ...`로 싱글톤을 직접 세팅해 init replay만 검증할 뿐,
**echo 경로를 한 번도 돌지 않았다**. 이 설계의 검증은:

- **driver→mirror 상태 전파 통합 테스트**: 두 ViewModel 인스턴스 간 실제 송수신을 시뮬레이션해
  echo·overwrite가 없음을 검증.
- 리매치 시 `resetAll`로 0-0 초기화 확인.
- mirror가 점수를 전송하지 않음(단방향) 확인.
- 인게임 점수가 스냅샷에 포함되어 전파됨 확인 (현재 0 전송 버그 회귀 가드).
- workoutEnd: sessionId 불일치 → dismiss 안 함 / 일치 → 함.
- 저장 upsert: 같은 sessionId 두 번 저장 → 1건.

> 시뮬레이터 단독 "안 보임 = 고쳐짐" 결론 금지. 통합 테스트 + 실기기 2대 수동 확인 병행.

---

## 영향 파일 (예상)

| 파일 | 변경 |
|------|------|
| `Shared/Services/WatchConnectivityService.swift` | workoutEnd에 sessionId 추가, 메시지/전송 정리 |
| `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | ScoreViewModel 소유, `isDriver`, 동기화 책임 이동, workoutEnd 가드 |
| `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | 동일 (워치) |
| `iOSApp/Features/Match/Score/ScoreViewModel.swift` | connectivity 의존 제거(순수화) + `resetAll(options:)` |
| `WatchApp/Features/Match/Score/ScoreViewModel.swift` | 동일 (전송 타이밍 버그 수정 포함) |
| `iOSApp/Features/Match/Score/ScoreView.swift` | `@ObservedObject`로 변경, 미러 입력 비활성+배지 |
| `WatchApp/Features/Match/Score/ScoreView.swift` | 동일 |
| `iOSApp/Features/WorkoutSession/WorkoutSessionView.swift` | workoutEnd 가드 적용 |
| `WatchApp/Features/WorkoutSession/WorkoutSessionView.swift` | 동일 |
| `Shared/Services/MatchPersistenceService.swift` | `upsert(by workoutSessionId)` 추가 |
| `iosTests/`, `watchosTests/` | 통합 테스트 미러링 |

---

## 호환성 / 마이그레이션

- 출시된 앱이지만 변경은 **런타임 동작/UI/동기화 프로토콜** 범위이고, SwiftData 스키마(`Match`/`SetRecord`)는
  바꾸지 않는다 → 데이터 마이그레이션 불필요.
- WC 메시지 포맷은 추가 필드(`workoutEnd`의 `sessionId`)에 한해 변경. 구버전과 혼용 시 가드는
  "sessionId 없으면 무시"로 안전 기본값을 둔다.
- 구버전 빌드가 설치된 기기와의 혼용은 권장하지 않으며(양쪽 업데이트 가정), 단방향 driver가
  스냅샷을 보내므로 mirror 구버전이라도 최소한 표시는 동작.

---

## 구현 순서 제안 (plan 분할 가이드)

1. **상태 소유권 이동** — ScoreViewModel을 WorkoutSessionViewModel로 끌어올리고 `resetAll` 도입
   (증상 1 해소, connectivity 의존은 아직 유지). 테스트: resetAll/리매치.
2. **동기화 책임 이동 + 단방향 authority** — driver/mirror, echo 제거, 스냅샷 전송 타이밍 수정
   (증상 3 해소). 테스트: driver→mirror 전파.
3. **workoutEnd 가드** (증상 2) + **미러 UI 배지/비활성**.
4. **저장 upsert** (중복 방지).

각 단계 독립 PR. **단계마다 워크플로우**: 구현(TDD) → 테스트 GREEN → **code-review (`/code-review`)** →
리뷰 지적은 `superpowers:receiving-code-review`로 검증 후 반영 → 가능하면 실기기 2대 확인 → PR.

> code-review는 각 단계의 머지 전 필수 게이트로 둔다(사용자 요청). 단방향 동기화·authority 판정처럼
> 미묘한 로직이 많아, 단계별 작은 diff에서 리뷰하는 편이 회귀를 더 잘 잡는다.
