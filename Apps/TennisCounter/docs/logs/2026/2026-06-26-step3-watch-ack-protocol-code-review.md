# 저장 실패 처리 3단계: Watch ack 프로토콜 구현 및 code-review 수정

**날짜:** 2026-06-26  
**관련 PR:** #10 (step3 구현), #11 (code-review follow-up)

---

## 배경

저장 실패 처리 시리즈의 3단계. Watch가 저장 요청(`matchSave`)을 보내면 iOS가 실제 persist 결과를 `matchSaveResult` 메시지로 회신하는 ack 프로토콜을 구현했다.

- 1단계: upsert 실패 시 컨텍스트 rollback (PR #8)
- 2단계: iOS 저장 버튼 실패 상태 표시 + 재시도 (PR #9)
- **3단계: Watch ack 프로토콜 (PR #10 + #11)**
- 4단계: Watch가 ack를 수신해 UI에 반영 (미구현)

---

## PR #10 구현 내용

### 추가된 것

- `WCMessageType.matchSaveResult` 케이스
- `MatchSaveResultMessage` struct — `sessionId: UUID`, `success: Bool`, `toDictionary()` / `init?(from:)` / memberwise init
- `WatchConnectivityService.receivedMatchSaveResult: MatchSaveResultMessage?` (@Published)
- `WatchConnectivityService.sendMatchSaveResult(_:)` — `sendReliably` 사용
- `handle(_:)` switch에 `matchSaveResult` 케이스 추가
- `WorkoutSessionViewModel.saveFromWatch` — `try? upsert` → do/catch + `sendMatchSaveResult` 회신
- `WorkoutSessionViewModel.saveFromWatchForTest` (#if DEBUG extension)

### 특이사항

- `#if DEBUG` 테스트 훅 블록 2개를 클래스 바깥 extension으로 통합 → `type_body_length` lint 위반 해소

---

## code-review 발견 및 수정 (PR #11)

PR #10 머지 후 `/code-review`를 실행한 결과 3건을 수정했다.

### [CONFIRMED] upsert silent nil → success: true 오발송

**근본 원인:**  
`MatchPersistenceService.upsert`의 `guard let context = modelContext else { return }` 가 throw 없이 조용히 return. `saveFromWatch`의 do/catch는 예외가 없으면 `success = true`로 유지되어 Watch에 `success: true`를 잘못 전송.

**수정:**  
`PersistenceError.notConfigured` 케이스 추가, `guard` 절을 `throw PersistenceError.notConfigured`로 변경.

```swift
// Before
guard let context = modelContext else { return }

// After
guard let context = modelContext else { throw PersistenceError.notConfigured }
```

**재현 경로:** 현재 앱 구조에서는 `init()` 내 동기 흐름으로 실운영 재현 가능성이 낮지만, `configure(with:)` 없이 사용하는 테스트/프리뷰 환경에서는 실제로 발생.

---

### [CONFIRMED] receivedMatchSaveResult 세션 시작 리셋 누락

**근본 원인:**  
`iOSApp.swift`의 `onMatchStart`/`onReceive(receivedSessionStart)` 두 곳과 `WatchApp/HomeView.swift`의 버튼 탭/`onReceive(receivedSessionStart)` 두 곳에서 `receivedWorkoutEnd`, `receivedMatchEnd`, `receivedMatchSave`는 nil로 초기화하지만 `receivedMatchSaveResult`는 누락됨.

**영향:** 4단계에서 Watch 측 `.compactMap(\.self).sink` 구독을 붙이면 이전 경기의 stale ack가 새 구독에 즉시 발화해 잘못된 저장 결과가 표시됨.

**수정:**  
4곳 모두에 `connectivity.receivedMatchSaveResult = nil` 추가.

---

### [PLAUSIBLE] MatchPersistenceService.shared 테스트 격리

**근본 원인:**  
`WorkoutSessionViewModelTests`, `MatchPersistenceServiceTests` 등 여러 테스트가 `MatchPersistenceService.shared`를 teardown 없이 `configure(with:)` 재구성. Swift Testing은 기본적으로 테스트를 병렬 실행함.

**실제 위험도:** `MatchPersistenceService`가 `@MainActor`이고 해당 테스트들도 모두 `@MainActor`이므로 진짜 data race는 아님. 그러나 테스트 순서/인터리빙에 따라 간헐적 상태 오염 가능성 존재.

**수정:**  
`WorkoutSessionViewModelTests`에 `@Suite(.serialized)` 추가.

---

## 4단계 구현 시 주의사항

- Watch 측 `WorkoutSessionViewModel`에서 `connectivity.$receivedMatchSaveResult`를 구독할 때, 구독 후 즉시 소비하고 `connectivity.receivedMatchSaveResult = nil`로 초기화해야 함 (다른 `receivedMatch*` 프로퍼티 패턴 참고)
- Watch SaveButton은 현재 `saved: Bool` 바이너리 상태만 있음 — `failed` + retry 상태 추가 필요 (iOS SaveButton의 `SaveButtonState` enum 참고)
- `sendReliably`로 전송된 ack는 Watch 미연결 시 `transferUserInfo`로 큐잉되므로 delayed delivery 가능. Watch 측에서 sessionId 검증 필수
