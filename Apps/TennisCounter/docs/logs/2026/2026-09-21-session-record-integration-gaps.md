# 세션 레코드 통합 공백 3건과 테스트 실행 환경 (2026-09-21)

`feat/session-centric-history` (#9 iOS 기록·요약 세션 중심 재편) 의 최종 전체 브랜치 리뷰가
통합 공백 3건을 지적한 뒤 중단됐다. 지적을 코드로 확인해 전부 실재함을 확인하고 고쳤다.
고치는 과정에서 이 브랜치의 테스트가 한 번도 실행된 적 없다는 것과, 실행을 막고 있던
환경 문제가 함께 드러나 같이 기록한다.

관련 문서 — [스펙](../../specs/ios/2026/2026-09-18-session-centric-history.md) ·
[플랜](../../plans/ios/2026/2026-09-18-session-centric-history.md)

## 1. 근본 원인 — 메시지 하나가 겸한 두 가지 일

`WorkoutEndMessage` 가 성격이 **반대인** 두 역할을 동시에 맡고 있었다.

| | 종료 **명령** | 세션 **기록** |
|---|---|---|
| 늦게 도착하면 | 버려야 한다 (끝난 세션의 화면을 되살린다) | **살려야 한다** (유일한 운반체) |
| 받는 주체 | 경기 화면이 떠 있을 때의 ViewModel | 앱이 살아 있는 내내 |

구독 위치와 staleness 정책이 전부 "명령" 기준으로 맞춰져 있었다. `WorkoutSessionRecord` 를
신설하면서 같은 메시지에 기록을 실었지만 그 두 축을 조정하지 않아, 기록이 세 갈래로 흘러내렸다.

## 2. 확인한 공백 3건

### ① 경기 없이 운동만 한 세션이 저장되지 않는다

워치는 `WorkoutSessionView.onAppear` 에서 곧바로 `startWorkout()` 하지만,
`sendSessionStart` 는 `startMatch` 에서만 나간다. 경기를 한 판도 시작하지 않고 끝내면

```
워치: 워크아웃 시작 → (경기 없음) → 종료, WorkoutEndMessage 송신
iOS : sessionStart 없음 → isMatchActive false → WorkoutSessionView 미생성
      → 구독자인 WorkoutSessionViewModel 자체가 없음 → 기록 유실
```

`MatchSessionGroup.group` 이 만드는 "경기 없음" 빈 세션 카드가 **주 경로에서 생기지 않았다.**
스펙에 적힌 기능이 동작하지 않는 상태였다.

### ② 폰에서 종료하면 최종값이 돌아오지 않는다

`iOS endSession(notifyRemote: true)` → 워치 `handleIncomingWorkoutEnd` →
`endWorkout(notifyRemote: false)`. 이 경로가 `stopWorkout()` 결과를 버렸다.
iOS 의 `endSession` 도 레코드를 만들지 않아, 그 워크아웃은 레코드가 비었다.

경기를 저장했다면 매치 누적 폴백으로 시간·칼로리는 살아남지만 **평균 심박은 `–` 로 떨어진다** —
`MatchSessionGroup.averageHeartRate` 는 의도적으로 폴백하지 않는다 (경기 구간 평균은 세션
평균이 아니다). 워크아웃 전체 평균을 아는 주체는 워치뿐이다.

### ③ 60초 staleness 필터가 기록을 폐기한다

`MatchConnectivity` 의 `onReceive(WorkoutEndMessage.self, maxAge: 60)`.
예전에는 늦게 온 종료를 버려도 미러 UI 가 안 닫히는 정도였지만, 지금은 그 메시지가
**세션 레코드의 유일한 운반체**다. 폰이 안 잡혀 `.reliable` 전송이 큐잉됐다가 60초 뒤
배달되면 기록이 영구 소실된다.

## 3. 수정 — 같은 메시지, 두 채널

`MessageRouter` 는 타입 하나에 등록을 여러 개 허용하고 **등록마다 `maxAge` 를 따로** 갖는다
(`MessageRouter.register` / `route`). 새 메시지 타입도 YJKit 변경도 없이 채널만 하나 더 열었다.

```
WorkoutEndMessage ─┬→ receivedWorkoutEnd    (maxAge 60)  → ViewModel: 화면 종료
                   └→ receivedSessionResult (상한 없음)   → Recorder: 레코드 저장
```

기록 채널에 상한을 두지 않은 근거 — 페이로드가 `startedAt`·`endedAt` 을 자체적으로 들고 있어
**늦게 와도 값이 틀어지지 않는다.** 늦은 기록은 맞는 기록이고, 없는 기록은 영구 손실이다.

| 파일 | 변경 |
|---|---|
| `Shared/Services/MatchConnectivity.swift` | `receivedSessionResult` 채널 추가 (두 번째 등록, 상한 없음) |
| `iOSApp/Services/WorkoutSessionRecorder.swift` | **신규.** 기록 채널을 구독해 `WorkoutSessionRecord` 로 저장 |
| `iOSApp/iOSApp.swift` | 레코더를 앱 루트에서 생성·보유 (앱 수명 내내 살아 있어야 ① 이 잡힌다) |
| `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `saveSessionRecord` 제거 — 저장 책임이 화면에서 떨어졌다 |
| `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `endWorkout` 이 종료 지시 주체와 무관하게 **항상** 최종값을 보낸다 |

**의도적으로 건드리지 않은 곳** — `MainTabView.onReceive` 와 `HomeView.onMatchStart` 가
`receivedWorkoutEnd = nil` 로 묵은 상태를 턴다. 여기에 `receivedSessionResult` 를 추가하면
저장 전에 기록이 날아간다.

에코 안전성 — 폰이 끝낸 경우 워치가 최종값을 되돌려 보내지만, iOS 수신 경로는
`endSession(notifyRemote: false)` 라 다시 보내지 않는다. 핑퐁이 없다.

[PR #28](https://github.com/qlrogo91lp/yj-apps/pull/28) 에 포함됐다.

## 4. 테스트 실행 환경 — 별건으로 드러난 것

이 브랜치의 17개 커밋은 **XCTest 가 한 번도 실행된 적 없었다.** 직전 세션의 Task 8 보고서에
`build-for-testing` 까지만 하고 테스트 런너는 돌리지 않았다고 적혀 있다.

### 병렬 실행이 결과를 망친다

기본값으로 돌리면 실패가 35개 나온다. 그런데 로그의 PID 가 테스트마다 바뀐다 —
테스트 호스트(앱 프로세스)가 죽고 다시 뜨기를 반복한다는 뜻이고, 죽은 프로세스에 묶여 있던
아직 실행도 안 된 테스트들이 `0.000 seconds` 로 실패 처리된다.

`-parallel-testing-enabled NO` 를 붙이면 **실패가 1개로 줄고, 오히려 더 빠르다.**

| | 소요 | 실패 |
|---|---|---|
| 기본값 (시뮬레이터 복제본 병렬) | 72.7초 | 35개 |
| `-parallel-testing-enabled NO` | 43.4초 | 1개 |

복제본이 죽고 다시 뜨는 비용이 병렬 이득보다 컸다.

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" \
  -destination "id=$IOS" -parallel-testing-enabled NO test
```

> 병렬은 **두 겹**이다. 위 플래그는 바깥(시뮬레이터 복제본)만 끈다. 이 저장소는 Swift Testing
> (`@Test`) 을 쓰는데 **한 프로세스 안에서도 테스트를 동시에 돌리는 것이 기본값**이라
> 안쪽 병렬은 그대로 남는다. 아래 실패가 거기서 나온 것으로 보인다.

### 남은 실패 1건은 기존 문제다

`WorkoutSessionViewModelTests.saveFromWatchPersistsMatch()` 가 실패한다.

```
NSInternalInconsistencyException: "No eligible connection available"
  NSManagedObjectContext.executeFetchRequest
  ← PersistenceCore.fetch(matching:sortBy:)
  ← MatchPersistenceService.fetchByWorkoutSession
```

컨테이너가 사라진 뒤 그 컨텍스트로 조회할 때 나는 CoreData 예외다. **단독으로 돌리면 통과한다** —
앞선 테스트가 남긴 상태에 오염된다. `MatchPersistenceService.shared` 가 싱글턴이라, 인메모리
컨테이너를 꽂았던 테스트가 끝나 컨테이너가 해제된 뒤 다른 테스트가 그 컨텍스트를 건드리면
정확히 이 모양이 된다 (Swift Testing 의 프로세스 내 동시 실행이 이를 더 잘 만든다).

**기준선 비교로 기존 문제임을 확정했다.** 수정 커밋 직전(`782db66`)에서 전체를 순차 실행해도
같은 테스트 하나가 같은 예외로 실패한다. 이번 수정과 무관하다.

| 커밋 | 순차 실행 결과 |
|---|---|
| `782db66` (수정 전) | `saveFromWatchPersistsMatch()` 1건 실패 |
| `0777fbf` (수정 후) | `saveFromWatchPersistsMatch()` 1건 실패 |

고치는 방향은 두 가지 — 해당 스위트에 `@Suite(.serialized)` 를 걸거나, 테스트가 싱글턴 대신
주입받은 서비스를 쓰게 바꾸는 것. 후자가 근본적이다 (`SessionPersistenceService` 는 이미
`SessionPersistenceServiceTests` 에서 직접 생성해 쓰고 있다).

## 5. 남은 것

`main` 리베이스(충돌 없음) → 푸시 → [PR #28](https://github.com/qlrogo91lp/yj-apps/pull/28) 까지는 끝났다.
같은 정리에서 `.gitignore` 에 있는데도 추적되고 있던 `.superpowers/sdd/` 산출물 2개의 추적을 끊었다.

- [ ] `saveFromWatchPersistsMatch` 테스트 오염 수정 — 별건 작업
- [ ] 실기기 확인
  - 워치에서 두 경기를 저장하고 약 5분 뒤 종료해, 카드 시간이 마지막 경기 종료가 아니라
    워크아웃 종료까지 포함하는지
  - 평균 심박이 `–` 가 아닌 값으로 채워지는지
  - **경기를 한 판도 저장하지 않은 워크아웃이 "경기 없음" 카드로 나타나는지** (① 회귀 확인)
  - **폰에서 종료한 워크아웃의 평균 심박이 채워지는지** (② 회귀 확인)
  - 구 세션이 시간·칼로리는 유지하고 심박은 `–` 로 표시되는지
  - 배포 후 구/신 레코드가 섞인 CloudKit 스키마·동기화
