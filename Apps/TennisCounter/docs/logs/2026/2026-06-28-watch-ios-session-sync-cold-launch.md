# 워치↔iOS 세션 동기화 — 콜드 런치 채택 / 종료 전파 버그 수정

## 작업일: 2026-06-28

> 실기기 2대(TestFlight) 반복 테스트로 발견·수정. PR #14 (`fix-cold-launch-session-adoption`).
> 같은 날 머지된 PR #13(라이프사이클 신뢰성 라운드2, [[2026-06-24-bidirectional-sync-root-cause-analysis]]의
> 후속) 위에서 추가로 드러난 **세션 채택/종료 전파** 문제를 다룬다.

## 배경 — 실사용 보고 (워치 driver, iOS mirror)

1. **워치 먼저 시작 → iOS 콜드 런치 시 매치 화면에 진입조차 못 함** (홈/모드선택 그대로).
2. (1을 고친 뒤) 점수는 동기화되는데 **워치에서 매치를 중간 종료(뒤로가기)해도 iOS는 점수화면에 멈춤**
   (상단 타이머도 계속 흐름).
3. **워치에서 운동(workout) 종료해도 iOS가 안 끝남.**

세 증상은 모두 "워치가 driver, iOS가 콜드 런치로 mirror가 되는" 경로에서 발생했다. 진단을 위해
`com.yj.TennisCounter.sync` subsystem에 `session`/`score` 카테고리 OSLog(`privacy:.public`)를 심어
TestFlight + Console.app으로 교차 확인했다.

---

## 근본 원인

### A. 콜드 런치 시 `receivedApplicationContext`를 안 읽음 (증상 1)

워치가 먼저 시작할 때 iOS 앱이 꺼져 있으면 `isReachable == false` → `sendSessionStart`가
`updateApplicationContext`로 전달된다(`WatchConnectivityService.send`). 그런데 `updateApplicationContext`
값은 받는 앱이 **실행 중일 때만** `didReceiveApplicationContext` 델리게이트가 호출되고, **앱이 꺼져
있다 콜드 런치되면 `session.receivedApplicationContext` 프로퍼티에만 남고 델리게이트는 불리지 않는다.**

기존 코드는 이 프로퍼티를 **어디서도 읽지 않았다**(`grep receivedApplicationContext` → 0건).
`activationDidCompleteWith`는 `isWatchReachable`만 세팅 → sessionStart 유실 → iOS 매치 진입 실패.

### B. iOS 원격 채택 시 자기 `sessionId`를 안 맞춤 (증상 2·3의 공통 원인)

iOS는 두 경로로 세션을 채택한다:
- VM 바인딩 `handleIncomingSessionStart` → `sessionId = msg.sessionId` 설정 ✅
- `WorkoutSessionView.onAppear`의 `remoteSession` → `startMatch(options:isRemote:true)` ❌

실제 콜드 런치 경로는 후자다(`iOSApp.swift`의 onReceive가 `receivedSessionStart`를 즉시 nil로
비워서 VM 바인딩이 발화하기 전에 onAppear가 채택). 그런데 **iOS `startMatch`는 `sessionId`를
받지도, 자기 것으로 맞추지도 않았다** → iOS의 `sessionId`가 init UUID 그대로.

결과로 **sessionId 가드가 걸린 신호가 전부 무시**됐다:

| 신호 | sessionId 가드 | 콜드런치 mirror에서 |
|------|----------------|---------------------|
| scoreState(점수) | 없음 | ✅ 동기화 (그래서 증상 1 수정 후 점수만 됨) |
| workoutEnd | 있음 (`id != sessionId → return`) | ❌ 무시 → iOS 안 끝남 (증상 3) |
| matchReset | 있음 | ❌ 무시 → 미러 안 초기화 (증상 2) |

워치 쪽 `startMatch`는 원래 `sessionId: UUID?`를 받아 `activeSessionId`를 맞추고 있었는데
**iOS만 이 파라미터가 빠진 비대칭**이 화근이었다.

### C. 매치 중간 종료(early exit)에 전파 신호 자체가 없음 (증상 2)

워치에서 뒤로가기로 매치를 버리면 `startNewMatch()`가 **로컬 상태만 초기화하고 iOS에 아무것도
안 보냈다.** 승부가 나는 자연 종료는 `matchEnd`를 보내지만, 중간 종료엔 대응 신호가 없었다.

---

## 수정

### 1. 콜드 런치 시 대기 컨텍스트 채택 (원인 A)
`activationDidCompleteWith`에서 활성화 직후 `session.receivedApplicationContext`를 읽어
비어있지 않으면 `handle()` 처리.

### 2. stale 세션 방지
applicationContext는 마지막 값을 계속 보관하므로, 운동 종료 시 `clearSessionContext()`로
outgoing 컨텍스트를 `sessionCleared` 마커로 비운다(워치 `endWorkout`·iOS `endSession`). 워치 크래시
등으로 못 비운 경우 대비해, 콜드 런치 채택 시 `workoutStartDate`가 6시간+ 오래된 sessionStart는
무시(`isSessionStartStale`).

### 3. iOS `startMatch`에 `sessionId` 동기화 (원인 B — 핵심)
```swift
func startMatch(options: MatchOptions, sessionId: UUID? = nil, isRemote: Bool = false) {
    ...
    if let sessionId { self.sessionId = sessionId }  // 원격 채택 시 상대 것으로 맞춤
    ...
}
```
`WorkoutSessionView.onAppear`가 `startMatch(options: remote.options, sessionId: remote.sessionId, isRemote: true)`로
호출. 이로써 workoutEnd·matchReset 가드가 통과한다.

### 4. 매치 중간 종료 전파 (원인 C)
새 메시지 `matchReset`. 드라이버가 `.playing`에서 나갈 때(`startNewMatch(notifyRemote:true)`) 전송,
미러는 받으면 모드선택으로 복귀(`startNewMatch(notifyRemote:false)`). 가드: 드라이버는 자기 신호
무시, sessionId 불일치 무시. 결과화면(`.finished`)에서의 "새 경기"는 broadcast 안 함(미러가 결과를
보고 저장할 수 있게). stale 안전: 콜드 런치 후 도착해도 미러가 이미 모드선택이라 no-op.

### 5. 진단 OSLog (session 카테고리)
sessionStart 송신(message/appContext 경로)·수신, 활성화 시 대기 컨텍스트, matchReset 송수신,
clearSessionContext를 `category:session`으로 기록. (점수 진단 `category:score`는 PR #13에서 추가)

---

## 커밋 (브랜치 `fix-cold-launch-session-adoption`)

- `b85f461` 콜드 런치 시 receivedApplicationContext 채택 + clearSessionContext + sessionStart staleness
- `8e28aaf` matchReset (드라이버 중간 종료 → 미러 초기화)
- `db2e3be` iOS 원격 채택 시 sessionId 동기화 (workoutEnd·matchReset 적용)

## 테스트

- 신규 단위테스트: `isSessionStartStale` 3종, matchReset 3종(미러 복귀/드라이버 무시/세션 불일치),
  sessionId 동기화 2종(workoutEnd·matchReset 적용). iOS 전체 GREEN, iOS·Watch 빌드 성공.
- WCSession 콜드 런치 동작은 유닛테스트 불가 → **실기기 2대 검증**으로 확인:
  증상 1·2·3 모두 해소 확인.

## 교훈

- **매 수정마다 TestFlight 재아카이브·업로드가 필요**하다. 같은 빌드로 재테스트해 "안 고쳐졌다"고
  오판하기 쉬움. Console에 신규 로그(`SENT matchReset` 등)가 뜨는지로 빌드 신선도를 판별.
- **증상이 화면상 동일해도 끊긴 계층이 다르다**(진입 못 함 / 점수만 / 종료 전파). 화면은 결과만,
  로그(경계별 계측)가 원인 위치를 가른다.
- **driver/mirror 비대칭을 의심하라.** 워치엔 있고 iOS엔 없던 `sessionId` 파라미터 하나가
  sessionId 가드 신호를 통째로 무력화했다. 양 플랫폼 대칭성 점검이 핵심.
