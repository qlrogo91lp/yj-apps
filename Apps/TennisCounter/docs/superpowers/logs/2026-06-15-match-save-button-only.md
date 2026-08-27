# 경기 점수는 저장 버튼을 눌렀을 때만 저장

## 작업일: 2026-06-15

## 증상

저장 버튼을 한 번도 누르지 않았는데도 경기 기록이 요약/히스토리(SwiftData)에 남아 있음. 의도된 동작은 "저장 버튼을 눌렀을 때만 persist".

## 원인 (양면 버그)

저장 구조를 추적해보니 실제 persist는 **오직 iOS의 CloudKit 동기화 SwiftData에만** 일어났고, 경로가 두 개였다:

1. `saveCurrentMatch()` — iOS 자체 경기의 저장 버튼 (정상, 명시적)
2. `saveFromWatch(msg)` — **Watch `MatchEnd` 수신 시 자동 호출** ← 버그

```swift
// iOS WorkoutSessionViewModel.init() — 기존
connectivity.$receivedMatchEnd
    .compactMap { $0 }
    .sink { [weak self] msg in
        self?.saveFromWatch(msg)        // ← 저장 버튼 없이 자동 persist
        ...
        self?.phase = .finished(session)
    }
```

추가로 **Watch 타겟엔 `ModelContainer`가 없어서** `MatchPersistenceService.save()`가 `modelContext == nil`로 그냥 리턴 → **Watch의 저장 버튼은 아무 일도 안 하는 no-op**였다.

정리하면 한 뿌리의 양면이었다:

| | 기존 동작 | 문제 |
|--|----------|------|
| iOS 자동저장 | Watch 경기 끝나면 버튼 없이 저장 | 저장 안 했는데 남음 |
| Watch 저장 버튼 | 누르면 `saved=true` UI만, 실제 저장 no-op | 저장 눌러도 안 남음 |

→ "Watch엔 저장소가 없어 저장을 iOS에 위임해야 하는데, 그걸 *버튼*이 아니라 *자동*으로 처리"한 게 근본 원인.

## 설계

**Watch 저장 버튼 → iOS에 "저장 요청" 전송 → iOS가 그때만 persist**

`MatchEnd`(결과 화면 표시용)와 저장 요청을 **별도 메시지 타입**으로 분리.

- `WCMessageType.matchSave` 신설. `MatchEndMessage`에 `toSaveDictionary()` 추가, `init?(from:)`는 `matchEnd`/`matchSave` 양쪽 페이로드를 모두 파싱.
- `WatchConnectivityService`: `@Published receivedMatchSave`, `sendMatchSave(_:)` 추가. `sendMatchEnd`/`sendMatchSave`가 공유하는 `sendReliably()` 헬퍼(reachable이면 `sendMessage`, 아니면 `transferUserInfo`).
- **iOS**: `receivedMatchEnd` 구독은 결과 화면 표시(`phase = .finished`)만, `saveFromWatch` 제거. 새 `receivedMatchSave` 구독에서만 persist.
- **Watch**: `saveCurrentMatch()`가 로컬 저장(no-op) 대신 `connectivity.sendMatchSave(...)` 전송. `MatchEndMessage` 생성은 `makeMatchEndMessage(session:)`로 공유.
- 워크아웃 재진입 지점(`iOSApp.swift` 2곳)에서 stale `receivedMatchSave = nil` 클리어 → 다음 세션에서 새 구독자가 직전 저장을 **replay 받아 중복 저장**하는 것 방지. (이전 `receivedScoreState`/`receivedMatchEnd`와 동일 패턴)

## 저장 동작 정리 (수정 후)

| 경기를 한 곳 | 저장 위치 | 동작 |
|---|---|---|
| iOS 직접 플레이 | iOS 결과뷰 저장 버튼 | ✅ 정상 (`_currentSession` 기반, 기존 유지) |
| Watch 플레이 | **Watch** 저장 버튼 | ✅ `sendMatchSave` → iOS persist |
| Watch 플레이 | iOS 결과뷰 저장 버튼 | ⚠️ 동작 안 함 (no-op) — Watch에서 저장하는 구조 |

**결정**: Watch 위주 사용이므로 "Watch발 경기는 Watch에서 저장"으로 충분. iOS 결과뷰에서도 저장 가능하게 하려면 중복 방지가 필요한데, 한 워크아웃 세션의 여러 경기가 `workoutSessionId`를 공유해 경기별 고유 키가 없어 단순 dedup이 어렵다 → 현재 구조 유지.

## 테스트

`iosTests/Shared/MatchEndMessageTests.swift` — `MatchEnd`/`MatchSave` 메시지 타입 구분과 save 페이로드 직렬화 왕복 검증. (저장 트리거가 두 타입으로 분리된 것이 fix의 핵심 계약.)

> 행위 단위(“`MatchEnd` 수신 시 저장 안 함”) 테스트는 `MatchPersistenceService`가 싱글톤 + 구독이 `receive(on: main)` 비동기라 결정적 검증이 어려워 직렬화 계약 테스트 + 빌드 + 실기기 확인으로 대체.

## 변경 파일

| 파일 | 변경 |
|------|------|
| `Shared/Services/WatchConnectivityService.swift` | `matchSave` 타입, `toSaveDictionary()`, `receivedMatchSave`, `sendMatchSave`, `sendReliably` 헬퍼, 수신 라우팅 |
| `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `receivedMatchEnd`에서 자동저장 제거, `receivedMatchSave` 구독 추가 |
| `iOSApp/iOSApp.swift` | 워크아웃 재진입 시 `receivedMatchSave = nil` 클리어 (2곳) |
| `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `saveCurrentMatch`가 `sendMatchSave` 전송, `makeMatchEndMessage` 헬퍼 추출 |
| `WatchApp/Features/Match/Result/MatchResultView.swift` | `saveMatch` non-throwing화, 미사용 `saveError` 제거 |
| `iosTests/Shared/MatchEndMessageTests.swift` | 신규 직렬화/타입 구분 테스트 |
