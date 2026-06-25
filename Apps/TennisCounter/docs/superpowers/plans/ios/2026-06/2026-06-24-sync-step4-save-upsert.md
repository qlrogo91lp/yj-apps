# 동기화 재설계 4단계: 저장 upsert Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **선행 조건:** 1~3단계와 독립적으로도 적용 가능하나, 순서상 마지막에 둔다.

**Goal:** 같은 경기(`workoutSessionId`)가 iOS·워치 양쪽 저장 버튼으로 중복 저장되는 것을 막는다. `MatchPersistenceService`에 upsert를 추가하고 양쪽 저장 경로가 이를 쓰게 한다.

**Architecture:** 저장 시 `workoutSessionId`로 기존 `Match`를 찾아 있으면 교체(삭제 후 insert), 없으면 insert한다. `saveCurrentMatch`(로컬)·`saveFromWatch`(워치 메시지) 모두 `upsert`를 경유한다.

**Tech Stack:** Swift, SwiftData, Swift Testing.

**작업 브랜치:** `git switch -c sync-step4-save-upsert`

**빌드/테스트 명령:** 1단계 plan 헤더 참조.

---

## File Structure

| 파일 | 변경 |
|------|------|
| `Shared/Services/MatchPersistenceService.swift` | `upsert(_:)` 추가 |
| `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `saveCurrentMatch`/`saveFromWatch`가 upsert 사용 |
| `iosTests/Shared/MatchPersistenceServiceTests.swift` (신규) | upsert 중복 방지 테스트 |

---

### Task 0: 브랜치 생성
- [ ] **Step 1:** `git switch -c sync-step4-save-upsert`

---

### Task 1: MatchPersistenceService.upsert

**Files:** Modify `Shared/Services/MatchPersistenceService.swift`, Test `iosTests/Shared/MatchPersistenceServiceTests.swift` (신규)

- [ ] **Step 1: 실패 테스트 — 같은 sessionId 두 번 저장 → 1건**

`iosTests/Shared/MatchPersistenceServiceTests.swift` 생성:
```swift
import SwiftData
import Testing
@testable import TennisCounter

@Suite @MainActor
struct MatchPersistenceServiceTests {
    private func makeService() throws -> MatchPersistenceService {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Match.self, SetRecord.self, configurations: config)
        let service = MatchPersistenceService.shared
        service.configure(with: ModelContext(container))
        return service
    }

    @Test func upsertSameSessionKeepsSingleRecord() throws {
        let service = try makeService()
        let sid = UUID()

        let m1 = Match(); m1.workoutSessionId = sid; m1.myTotalSets = 1
        try service.upsert(m1)

        let m2 = Match(); m2.workoutSessionId = sid; m2.myTotalSets = 2
        try service.upsert(m2)

        let all = try service.fetchByWorkoutSession(sid)
        #expect(all.count == 1)
        #expect(all.first?.myTotalSets == 2) // 최신으로 갱신
    }
}
```
> 주의: `MatchPersistenceService`가 싱글톤이라 테스트 간 컨텍스트가 공유될 수 있다. in-memory 컨테이너로 매 테스트 재구성한다.

- [ ] **Step 2: 실패 확인** — `upsert` 없음.

- [ ] **Step 3: 구현**

`Shared/Services/MatchPersistenceService.swift`에 추가:
```swift
    func upsert(_ match: Match) throws {
        guard let context = modelContext else { return }
        if let sid = match.workoutSessionId {
            let existing = try fetchByWorkoutSession(sid)
            for old in existing { context.delete(old) }
        }
        context.insert(match)
        try context.save()
    }
```

- [ ] **Step 4: 통과 확인** — PASS.

- [ ] **Step 5: 커밋**
```bash
git add Shared/Services/MatchPersistenceService.swift iosTests/Shared/MatchPersistenceServiceTests.swift
git commit -m "✨ MatchPersistenceService.upsert (sessionId 중복 방지)"
```

---

### Task 2: 저장 경로가 upsert 사용

**Files:** Modify `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`

- [ ] **Step 1: 구현**

`saveCurrentMatch()`:
```swift
    func saveCurrentMatch() {
        guard let session = _currentSession else { return }
        let match = buildMatchFromSession(session)
        try? MatchPersistenceService.shared.upsert(match)
    }
```

`saveFromWatch(_:)`:
```swift
    private func saveFromWatch(_ msg: MatchEndMessage) {
        let match = buildMatchFromMessage(msg)
        try? MatchPersistenceService.shared.upsert(match)
    }
```

- [ ] **Step 2:** iOS 빌드 → BUILD SUCCEEDED, 테스트 GREEN

- [ ] **Step 3: 커밋**
```bash
git add iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift
git commit -m "♻️ 저장 경로를 upsert로 통일 (중복 방지)"
```

---

### Task 3: 전체 검증 + code-review

- [ ] **Step 1:** iOS·Watch 빌드/테스트 GREEN
- [ ] **Step 2:** `make fix && make lint`
- [ ] **Step 3:** `/code-review` → `superpowers:receiving-code-review`로 반영
- [ ] **Step 4: 수동 확인**
  - 워치에서 경기 저장 → iOS History 1건
  - 같은 경기를 iOS 결과화면에서도 저장 → 여전히 1건 (중복 안 생김)

---

## 이 단계가 검증하는 것

- 같은 `workoutSessionId` 경기는 어디서 몇 번 저장하든 History에 1건만 남는다.
- (오염 저장은 1·2단계의 driver 모델로 이미 제거됨 — 저장 출처가 깨끗한 `_currentSession`.)
