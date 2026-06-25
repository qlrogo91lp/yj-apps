# 저장 실패 처리 1단계: upsert 컨텍스트 rollback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **선행 조건:** 없음. 이 시리즈의 1단계.

**Goal:** `MatchPersistenceService.upsert`가 `context.save()` 실패 시 pending 변경(`delete`/`insert`)을 `context.rollback()`으로 정리하고 에러를 전파하게 한다. 컨텍스트가 깨진 상태로 남아 이후 무관한 저장에 영향을 주는 것을 막는다.

**Architecture:** `do { try context.save() } catch { context.rollback(); throw ... }`. SwiftData는 `save()`를 깨끗하게 강제 실패시킬 fault-injection 지점이 없어(모델에 unique 제약 없음), 이 변경은 실패 분기에 대한 새 자동 테스트 없이 구현하고 코드 리뷰로 검증한다 — 기존 성공 경로 테스트로 회귀만 확인한다.

**Tech Stack:** Swift, SwiftData, Swift Testing.

**작업 브랜치:** `git switch -c failure-handling-step1-context-rollback`

**빌드/테스트 명령:**
```bash
# iOS 빌드
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# iOS 테스트 (특정 클래스만)
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iosTests/MatchPersistenceServiceTests

# Watch 빌드 (Shared 파일이라 Watch 타겟 컴파일도 확인 필요)
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build

# Lint/Format
make fix && make lint
```
> Watch 시뮬레이터 id가 필요한 테스트 실행 명령은 4단계 plan 참조. 이 plan은 Watch는 빌드만 확인한다(테스트 실행 불필요 — 이 변경은 Watch 코드를 호출하지 않음).

---

## File Structure

| 파일 | 변경 |
|------|------|
| `Shared/Services/MatchPersistenceService.swift` | `PersistenceError` 추가, `upsert(_:)`에 실패 시 rollback 추가 |

---

### Task 0: 브랜치 생성
- [ ] **Step 1:** `git switch -c failure-handling-step1-context-rollback`

---

### Task 1: upsert 실패 시 rollback

**Files:** Modify `Shared/Services/MatchPersistenceService.swift`, Test `iosTests/Shared/MatchPersistenceServiceTests.swift` (기존 파일, 회귀 확인용)

- [ ] **Step 1: 현재 코드 확인**

`Shared/Services/MatchPersistenceService.swift`의 현재 `upsert(_:)`는 다음과 같다:
```swift
    func upsert(_ match: Match) throws {
        guard let context = modelContext else { return }
        if let sid = match.workoutSessionId {
            let existing = try fetchByWorkoutSession(sid)
            for old in existing {
                context.delete(old)
            }
        }
        context.insert(match)
        try context.save()
    }
```

- [ ] **Step 2: 구현**

파일 맨 위 `import SwiftData` 다음 줄에 추가:
```swift
enum PersistenceError: Error {
    case saveFailed(Error)
}
```

`upsert(_:)`를 다음으로 교체:
```swift
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

> 자동 테스트로 강제할 수 없는 실패 분기(`catch`)는 코드 리뷰 + 수동 추론으로 검증한다
> (`docs/superpowers/specs/ios/2026-06-25-upsert-failure-handling-design.md`의 "자동 테스트로
> 다루기 어려운 부분" 참조). 이 Task는 성공 경로 회귀만 확인한다.

- [ ] **Step 3: 회귀 테스트 실행 — 성공 경로가 그대로 통과하는지 확인**

Run: `xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iosTests/MatchPersistenceServiceTests`
Expected: PASS (`upsertSameSessionKeepsSingleRecord`)

- [ ] **Step 4: Watch 빌드 확인** (Shared 파일 변경이라 Watch 타겟도 컴파일돼야 함)

Run: `xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: 커밋**

```bash
git add Shared/Services/MatchPersistenceService.swift
git commit -m "🐛 upsert 저장 실패 시 컨텍스트 rollback (stuck 방지)"
```

---

### Task 2: 전체 검증 + code-review

- [ ] **Step 1:** iOS 빌드/테스트 전체 GREEN

Run: `xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

- [ ] **Step 2:** `make fix && make lint` — 모두 클린

- [ ] **Step 3:** `/code-review` 실행 → 지적 사항은 `superpowers:receiving-code-review`로 검증 후 반영

- [ ] **Step 4:** 위 검증·반영이 끝나면 `superpowers:finishing-a-development-branch`로 브랜치 정리 (PR 생성 또는 머지는 사용자 선택에 따름)

---

## 이 단계가 검증하는 것

- `upsert`가 저장에 실패해도(코드 리뷰로 추론한 시나리오 기준) `ModelContext`에 pending 변경이
  남지 않는다 — 이후 무관한 저장이 이번 실패의 영향을 받지 않는다.
- 성공 경로(기존 동작)는 회귀 없이 그대로 동작한다.

> 호출부(`saveCurrentMatch`/`saveFromWatch`)는 아직 `try?`로 에러를 삼킨다 — 2·3단계에서 고친다.
