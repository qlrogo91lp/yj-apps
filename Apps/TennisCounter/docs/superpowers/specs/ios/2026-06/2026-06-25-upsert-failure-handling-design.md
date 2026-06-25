# 저장 실패 처리 — upsert 컨텍스트 복구 + 성공/실패 UI 반영

## 작성일: 2026-06-25

## 배경

`docs/superpowers/plans/ios/2026-06-24-sync-step4-save-upsert.md` 구현 후 `/code-review`에서
PLAUSIBLE 판정을 받은 이슈: `MatchPersistenceService.upsert`는 `context.delete(old)` →
`context.insert(match)` → `context.save()` 순서로 동작하는데, `save()`가 실패해도 pending
delete/insert를 되돌리지 않는다. `ModelContext`가 앱 전역에서 공유되는 장수명 인스턴스이므로,
실패가 컨텍스트에 그대로 남으면 이후의 무관한 저장 작업까지 영향받을 수 있다.

이 이슈를 설명하는 과정에서 더 근본적인 기존 문제가 드러났다:

- `saveCurrentMatch()`/`saveFromWatch()` 모두 `try?`로 에러를 삼킨다. **저장이 실패해도 호출부는
  알 수 없다.**
- `MatchResultView`(iOS·Watch 공통 패턴)는 저장 버튼을 누르면 성공/실패 무관하게 무조건
  `saved = true`를 표시한다. 즉 지금도 저장이 실패하면 사용자는 "저장됨"을 보고 안심하지만
  실제로는 기록이 사라진다.
- Watch는 로컬 저장소가 없어 항상 iOS로 저장 요청을 보내는데(`sendMatchSave`), iOS가 실제로
  persist에 성공했는지에 대한 응답(ack)이 프로토콜에 없다. Watch의 "저장됨" 표시는 메시지를
  보냈다는 사실만 반영할 뿐, iOS의 실제 저장 결과와 무관하다.

이 설계는 컨텍스트 stuck 방지(원래 code-review 지적)와, 저장 성공/실패를 사용자에게 정확히
보여주는 것(부수적으로 발견된 더 큰 문제) 두 가지를 함께 다룬다.

---

## 목표 / 비목표

### 목표

- `upsert` 실패 시 `context.rollback()`으로 pending 변경을 정리해, 이후 무관한 저장이
  영향받지 않게 한다.
- iOS 로컬 저장 경로(`saveCurrentMatch` → `MatchResultView`)가 실제 성공/실패를 사용자에게
  보여주고, 실패 시 같은 버튼으로 재시도할 수 있게 한다.
- Watch 저장 경로(`saveFromWatch`)도 iOS의 실제 persist 결과를 ack로 Watch에 회신해,
  Watch의 저장 버튼이 진짜 상태(성공/실패/확인 중)를 보여주게 한다.
- ack가 일정 시간 내 오지 않으면 "확인 안됨, 다시 시도" 상태로 전환해 무한 로딩을 막는다.

### 비목표 (YAGNI)

- 저장 실패 원인별 세분화된 에러 메시지 (이번엔 성공/실패 binary만 다룬다)
- Watch에 로컬 영속화(SwiftData) 추가 — Watch는 여전히 저장소가 없고 iOS에 위임하는 구조 유지
- 오프라인 재시도 자동화/큐 강화 — 기존 `transferUserInfo` 큐잉을 그대로 사용하고, 그 이상의
  재전송 보장 메커니즘은 만들지 않음
- `context.rollback()`이 이 호출과 무관한 다른 pending 변경까지 되돌릴 수 있는 이론적 한계
  자체를 구조적으로 막는 것 (현재 앱이 `@MainActor` 단일 컨텍스트라 발생 가능성이 낮다고 보고
  감내함)

---

## 확정된 핵심 결정

| # | 결정 | 선택 |
|---|------|------|
| 1 | 컨텍스트 복구 | `context.save()` 실패 시 `context.rollback()` 후 에러를 그대로 throw |
| 2 | iOS 로컬 저장 UI | 에러 문구 대신, 같은 저장 버튼이 실패 시 `failed` 상태로 바뀌고 탭하면 재시도 |
| 3 | Watch ack 방식 | 별도 `matchSaveResult` 메시지를 기존 `sendReliably` 패턴으로 회신 (reachable 즉시, 아니면 큐잉) |
| 4 | Watch ack 타임아웃 | N초(기본 8초) 내 ack 없으면 `failed`로 전환 + 수동 재시도. 무한 대기 금지 |
| 5 | 재시도 경합 처리 | 토큰(증가하는 카운터)으로, 새 시도가 진행 중일 때 이전 시도의 지연된 타임아웃이 상태를 덮어쓰지 않게 함 |

---

## 아키텍처

### 1. `MatchPersistenceService.upsert` — 컨텍스트 복구

```swift
enum PersistenceError: Error {
    case saveFailed(Error)
}

func upsert(_ match: Match) throws {
    guard let context = modelContext else { return }
    if let sid = match.workoutSessionId {
        let existing = try fetchByWorkoutSession(sid)
        for old in existing {
            context.delete(old)
        }
    }
    context.insert(match)
    do {
        try context.save()
    } catch {
        context.rollback()
        throw PersistenceError.saveFailed(error)
    }
}
```

`save()`가 실패하면 이 호출에서 만든 delete/insert를 `rollback()`으로 정리하고 에러를
그대로 전파한다. 호출부가 `try?`로 삼키지 않고 성공/실패를 받아 처리하는 것이 다음 두
섹션의 전제다.

### 2. iOS 로컬 저장 경로

`WorkoutSessionViewModel.saveCurrentMatch()`가 `Bool`을 반환하도록 변경:

```swift
@discardableResult
func saveCurrentMatch() -> Bool {
    guard let session = _currentSession else { return false }
    let match = buildMatchFromSession(session)
    do {
        try MatchPersistenceService.shared.upsert(match)
        return true
    } catch {
        return false
    }
}
```

`SaveButton`(iOS)을 `Bool` 2-state에서 `idle`/`saved`/`failed` 3-state로 확장. `failed`는
`disabled`가 아니므로 탭하면 `action`이 다시 호출되어 재시도된다 — 별도 재시도 버튼을 새로
만들지 않는다. `MatchResultView`는 `viewModel.saveCurrentMatch()`의 반환값으로 상태를 설정한다.

### 3. Watch ack 프로토콜

`Shared/Services/WatchConnectivityService.swift`에 메시지 타입과 모델 추가:

```swift
private enum WCMessageType: String {
    // ...
    case matchSaveResult
}

struct MatchSaveResultMessage {
    let sessionId: UUID
    let success: Bool

    func toDictionary() -> [String: Any] {
        ["type": WCMessageType.matchSaveResult.rawValue,
         "sessionId": sessionId.uuidString,
         "success": success]
    }

    init?(from dict: [String: Any]) {
        guard dict["type"] as? String == WCMessageType.matchSaveResult.rawValue,
              let idStr = dict["sessionId"] as? String,
              let id = UUID(uuidString: idStr),
              let success = dict["success"] as? Bool else { return nil }
        sessionId = id
        self.success = success
    }
}
```

`@Published var receivedMatchSaveResult: MatchSaveResultMessage?`와
`sendMatchSaveResult(_:)`(기존 `sendMatchSave`와 동일하게 `sendReliably` 사용)를 추가하고,
`handle()` 스위치에 케이스를 추가한다.

iOS `WorkoutSessionViewModel.saveFromWatch`가 upsert 결과를 ack로 회신:

```swift
private func saveFromWatch(_ msg: MatchEndMessage) {
    let match = buildMatchFromMessage(msg)
    let success = (try? MatchPersistenceService.shared.upsert(match)) != nil
    connectivity.sendMatchSaveResult(MatchSaveResultMessage(sessionId: msg.sessionId, success: success))
}
```

### 4. Watch ack 수신 + 타임아웃 + UI

`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`:

```swift
enum SaveAckState { case idle, pending, succeeded, failed }
@Published var saveAckState: SaveAckState = .idle
private var saveAttemptToken = 0
private let ackTimeoutSeconds: TimeInterval  // init(ackTimeoutSeconds: TimeInterval = 8, ...)

func saveCurrentMatch() {
    guard let session = _currentSession else { return }
    saveAttemptToken += 1
    let token = saveAttemptToken
    saveAckState = .pending
    connectivity.sendMatchSave(makeMatchEndMessage(session: session))
    DispatchQueue.main.asyncAfter(deadline: .now() + ackTimeoutSeconds) { [weak self] in
        guard let self, self.saveAttemptToken == token, self.saveAckState == .pending else { return }
        self.saveAckState = .failed
    }
}

private func handleMatchSaveResult(_ result: MatchSaveResultMessage) {
    guard result.sessionId == activeSessionId else { return }
    connectivity.receivedMatchSaveResult = nil
    saveAckState = result.success ? .succeeded : .failed
}
```

`ackTimeoutSeconds`는 기존 `metricsThrottle`처럼 `init`에서 주입 가능하게 만들어 테스트에서
짧은 값을 쓸 수 있게 한다. `saveAttemptToken` 비교는 "이 타임아웃이 발동했을 때, 그게 여전히
가장 최신 시도에 대한 것인지"를 확인하는 표식이다 — 재시도 후 새 시도가 진행 중일 때 이전
시도의 지연된 타임아웃이 새 상태를 덮어쓰는 경합을 막는다.

Watch `SaveButton`/`MatchResultView`는 iOS와 동일한 패턴으로 `idle`/`pending`/`succeeded`/`failed`
4-state 라벨·아이콘 매핑, `failed` 탭 시 재시도.

---

## 테스트 전략

**자동 테스트로 다루는 부분:**

1. `MatchSaveResultMessage` 직렬화 round-trip, 잘못된 타입/필드 누락 시 `nil` 반환
2. Watch `handleMatchSaveResult` — `sessionId` 불일치 시 무시, 일치 시 `succeeded`/`failed` 반영
3. Watch 타임아웃/토큰 로직 — 짧은 `ackTimeoutSeconds` 주입으로 "타임아웃 후 failed 전환"과
   "재시도 시 이전 타임아웃이 새 시도를 덮어쓰지 않음" 검증
4. iOS `saveCurrentMatch`/`saveFromWatch` 성공 경로 — in-memory 컨테이너로 `upsert` 성공 시
   `true`/ack `success: true` 반환 검증

**자동 테스트로 다루기 어려운 부분 (알려진 한계):**

- `upsert`의 `context.save()` 실패 → `rollback()` 분기. `Match` 모델에 `@Attribute(.unique)` 등
  제약이 없어 SwiftData의 `save()`를 깨끗하게 강제 실패시킬 방법이 없다. 모델에 인위적 제약을
  추가하거나 `ModelContext`를 추상화하는 건 이번 범위를 넘는 침습적 변경이므로, 이 분기는
  코드 리뷰 + 수동 추론으로 검증하고 자동 테스트 갭으로 명시한다.
- 실기기 간 ack round-trip 전체 흐름(Watch 저장 → iOS upsert → ack 회신 → Watch UI 갱신).
  `watch-sync-simulator-trap` 메모리에 기록된 대로 연동 동작은 시뮬레이터에서 재현되지 않으므로
  실기기 2대로 수동 검증이 필요하다.

---

## 영향 파일 (예상)

| 파일 | 변경 |
|------|------|
| `Shared/Services/MatchPersistenceService.swift` | `upsert` 실패 시 `rollback()` + throw |
| `Shared/Services/WatchConnectivityService.swift` | `matchSaveResult` 메시지/모델 추가 |
| `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `saveCurrentMatch` Bool 반환, `saveFromWatch` ack 회신 |
| `iOSApp/Features/Match/Result/Components/SaveButton.swift` | `idle`/`saved`/`failed` 3-state |
| `iOSApp/Features/Match/Result/MatchResultView.swift` | 저장 결과를 `SaveButton` 상태에 반영 |
| `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `saveAckState`, 토큰 기반 타임아웃 |
| `WatchApp/Features/Match/Result/Components/SaveButton.swift` | `idle`/`pending`/`succeeded`/`failed` 4-state |
| `WatchApp/Features/Match/Result/MatchResultView.swift` | ack 상태를 `SaveButton`에 반영 |
| `iosTests/`, `watchosTests/` | 위 테스트 전략 항목 반영 |

---

## 호환성

- SwiftData 스키마(`Match`/`SetRecord`) 변경 없음 — 마이그레이션 불필요.
- WC 메시지 포맷은 `matchSaveResult` 타입 추가뿐. 구버전 iOS/Watch와 혼용 시, 구버전은 이
  메시지를 모르므로 그냥 무시한다 — Watch가 신버전인데 iOS가 구버전이면 ack를 못 받아
  타임아웃 후 `failed`로 보이지만(실제로는 저장됐을 수 있음), 기존 동작(무조건 "저장됨" 오표시)
  보다는 안전한 방향의 실패다.

---

## 구현 순서 제안 (plan 분할 가이드)

1. **`MatchPersistenceService.upsert` 컨텍스트 복구** — rollback + throw. 테스트: 저장 성공
   경로 유지 확인(기존 테스트), 실패 경로는 코드 리뷰로 검증(자동 테스트 갭 명시).
2. **iOS 로컬 저장 경로 UI** — `saveCurrentMatch` Bool 반환, `SaveButton` 3-state, `MatchResultView` 연결.
3. **Watch ack 프로토콜** — `matchSaveResult` 메시지/모델, iOS `saveFromWatch` ack 회신.
4. **Watch ack 수신 + 타임아웃 + UI** — `saveAckState`, 토큰 기반 타임아웃, `SaveButton` 4-state.

각 단계 독립 PR. 단계마다: 구현(TDD) → 테스트 GREEN → `/code-review` → 지적 반영 →
가능하면 실기기 2대 확인 → PR.
