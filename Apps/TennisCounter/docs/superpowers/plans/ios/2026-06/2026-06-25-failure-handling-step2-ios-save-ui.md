# 저장 실패 처리 2단계: iOS 로컬 저장 UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **선행 조건:** 1단계(`2026-06-25-failure-handling-step1-context-rollback.md`)가 머지되어
> `MatchPersistenceService.upsert`가 실패 시 `throw`하는 상태여야 한다.

**Goal:** iOS 결과 화면(`MatchResultView`)의 저장 버튼이 실제 저장 성공/실패를 보여주고,
실패 시 같은 버튼을 다시 탭해 재시도할 수 있게 한다. 지금은 저장 시도만 하면 성공/실패
무관하게 무조건 "저장됨"을 보여준다 — 이 버그를 고친다.

**Architecture:** `WorkoutSessionViewModel.saveCurrentMatch()`가 `Bool`을 반환하도록 바꾸고,
`SaveButton`을 `idle`/`saved`/`failed` 3-state로 확장한다. `failed`는 비활성화하지 않아 버튼을
다시 탭하면 `action`이 그대로 재호출되어 재시도된다 — 별도 재시도 버튼을 만들지 않는다.

**Tech Stack:** Swift, SwiftUI, SwiftData, Swift Testing.

**작업 브랜치:** `git switch -c failure-handling-step2-ios-save-ui`

**빌드/테스트 명령:**
```bash
# iOS 빌드
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# iOS 테스트 (특정 클래스만)
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iosTests/WorkoutSessionViewModelTests

# iOS 전체 테스트
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Lint/Format
make fix && make lint
```

---

## File Structure

| 파일 | 변경 |
|------|------|
| `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `saveCurrentMatch()`가 `Bool` 반환 |
| `iOSApp/Features/Match/Result/Components/SaveButton.swift` | `idle`/`saved`/`failed` 3-state |
| `iOSApp/Features/Match/Result/MatchResultView.swift` | 반환값을 버튼 상태에 매핑 |
| `iOSApp/en.lproj/Localizable.strings`, `ko.lproj/Localizable.strings` | `result_save_failed` 키 추가 |
| `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` | 성공 경로 반환값 테스트, 기존 no-op 테스트 갱신 |

---

### Task 0: 브랜치 생성
- [x] **Step 1:** `git switch -c failure-handling-step2-ios-save-ui`

---

### Task 1: `saveCurrentMatch()` Bool 반환

**Files:**
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
- Test: `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`

- [x] **Step 1: 실패 테스트 작성**

`iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` 맨 위 import 블록을 다음으로 교체
(SwiftData 추가, 알파벳 순서 유지):
```swift
import Foundation
import SwiftData
@testable import TennisCounter
import Testing
```

파일 안의 기존 테스트
```swift
    @Test @MainActor func matchSessionSaveWithNoSessionIsNoOp() {
        let vm = WorkoutSessionViewModel()
        vm.saveCurrentMatch() // _currentSession nil이면 guard에서 리턴
    }
```
를 다음으로 교체 (반환값을 실제로 검증):
```swift
    @Test @MainActor func matchSessionSaveWithNoSessionIsNoOp() {
        let vm = WorkoutSessionViewModel()
        #expect(vm.saveCurrentMatch() == false) // _currentSession nil이면 guard에서 false 리턴
    }
```

그리고 같은 파일에 새 테스트를 추가:
```swift
    @Test @MainActor func saveCurrentMatchReturnsTrueOnSuccess() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Match.self, SetRecord.self, configurations: config)
        MatchPersistenceService.shared.configure(with: ModelContext(container))

        let vm = WorkoutSessionViewModel()
        vm.startSession()
        vm.startMatch(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
        vm.finishMatch(result: .win, completedSets: [(my: 6, your: 4)])

        #expect(vm.saveCurrentMatch() == true)
    }
```

> `MatchPersistenceService.shared`는 싱글톤이라 테스트 간 컨텍스트가 공유된다. 다른 테스트가
> 먼저 `configure`를 호출했어도 이 테스트가 다시 in-memory 컨테이너로 덮어쓰므로 순서 의존성은
> 없다 (기존 `MatchPersistenceServiceTests`도 동일한 패턴 사용).

- [x] **Step 2: 실패 확인**

Run: `xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iosTests/WorkoutSessionViewModelTests`
Expected: BUILD FAILED — `saveCurrentMatch()`가 `Void`를 반환해 `== false`/`== true` 비교가
컴파일되지 않음 ("cannot convert value of type '()' to expected type 'Bool'" 류 에러)

- [x] **Step 3: 구현**

`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`의 현재
```swift
    func saveCurrentMatch() {
        guard let session = _currentSession else { return }
        let match = buildMatchFromSession(session)
        try? MatchPersistenceService.shared.upsert(match)
    }
```
를 다음으로 교체:
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

- [x] **Step 4: 통과 확인**

Run: `xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:iosTests/WorkoutSessionViewModelTests`
Expected: PASS

- [x] **Step 5: 커밋**

```bash
git add iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift
git commit -m "✨ saveCurrentMatch가 저장 성공/실패를 Bool로 반환"
```

---

### Task 2: SaveButton 3-state + MatchResultView 연결 + 로컬라이즈

**Files:**
- Modify: `iOSApp/Features/Match/Result/Components/SaveButton.swift`
- Modify: `iOSApp/Features/Match/Result/MatchResultView.swift`
- Modify: `iOSApp/en.lproj/Localizable.strings`, `iOSApp/ko.lproj/Localizable.strings`

(View는 CLAUDE.md 테스트 컨벤션상 자동 테스트 대상이 아니다 — 시뮬레이터에서 수동 확인한다.)

- [x] **Step 1: 로컬라이즈 키 추가**

`iOSApp/ko.lproj/Localizable.strings`에서 다음 줄(현재 84-85번째 줄 부근)을 찾는다:
```
"result_save" = "저장";
"result_saved" = "저장됨";
```
바로 아래에 추가:
```
"result_save_failed" = "저장 실패, 다시 시도";
```

`iOSApp/en.lproj/Localizable.strings`에서 동일하게:
```
"result_save" = "Save";
"result_saved" = "Saved";
```
바로 아래에 추가:
```
"result_save_failed" = "Save Failed, Retry";
```

- [x] **Step 2: SaveButton.swift 교체**

`iOSApp/Features/Match/Result/Components/SaveButton.swift` 전체를 다음으로 교체:
```swift
import SwiftUI

enum SaveButtonState: Equatable {
    case idle, saved, failed
}

struct SaveButton: View {
    let state: SaveButtonState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .disabled(state == .saved)
    }

    private var icon: String {
        switch state {
        case .idle: "square.and.arrow.down"
        case .saved: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var label: String {
        switch state {
        case .idle: String(localized: "result_save")
        case .saved: String(localized: "result_saved")
        case .failed: String(localized: "result_save_failed")
        }
    }

    private var tint: Color {
        switch state {
        case .idle: .green
        case .saved: .gray
        case .failed: .orange
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        SaveButton(state: .idle) {}
        SaveButton(state: .saved) {}
        SaveButton(state: .failed) {}
    }
    .padding()
}
```

> 기존 파일이 `Bool` 기반(`saved: Bool`) 2-state였다면 위 내용으로 완전히 대체한다. 기존 파일의
> 정확한 폰트/패딩 값과 다르면(리팩터 중 변경됐을 수 있음) 기존 값을 우선하고 `state`/`enum`
> 구조만 이 코드대로 적용한다.

- [x] **Step 3: MatchResultView.swift 수정**

현재:
```swift
struct MatchResultView: View {
    let session: MatchSession
    @ObservedObject var viewModel: WorkoutSessionViewModel

    @State private var saved = false
    ...
            HStack(spacing: 16) {
                    SaveButton(saved: saved) { saveMatch() }
                    RematchButton { viewModel.restartMatch() }
                }
    ...
    private func saveMatch() {
        viewModel.saveCurrentMatch()
        withAnimation { saved = true }
    }
}
```

`@State private var saved = false`를 다음으로 교체:
```swift
    @State private var saveState: SaveButtonState = .idle
```

`SaveButton(saved: saved) { saveMatch() }`를 다음으로 교체:
```swift
                    SaveButton(state: saveState) { saveMatch() }
```

`saveMatch()` 함수를 다음으로 교체:
```swift
    private func saveMatch() {
        withAnimation {
            saveState = viewModel.saveCurrentMatch() ? .saved : .failed
        }
    }
```

- [x] **Step 4: 빌드 확인**

Run: `xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: BUILD SUCCEEDED

- [x] **Step 5: 시뮬레이터 수동 확인 (성공 경로)**

시뮬레이터에서 앱 실행 → 경기 시작 → 종료 → 결과 화면에서 저장 버튼 탭 → "저장됨"으로
바뀌고 비활성화되는지 확인. (실패 경로는 디스크 강제 실패가 어려워 시뮬레이터에서 재현하지
않는다 — 코드 리뷰로 로직만 검증한다.)

- [x] **Step 6: 커밋**

```bash
git add iOSApp/Features/Match/Result/Components/SaveButton.swift iOSApp/Features/Match/Result/MatchResultView.swift iOSApp/en.lproj/Localizable.strings iOSApp/ko.lproj/Localizable.strings
git commit -m "✨ 저장 실패 시 버튼에 실패 상태 표시 + 재시도"
```

---

### Task 3: 전체 검증 + code-review

- [x] **Step 1:** iOS 빌드/테스트 전체 GREEN

Run: `xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`

- [x] **Step 2:** `make fix && make lint` — 모두 클린

- [x] **Step 3:** `/code-review` 실행 → 지적 사항은 `superpowers:receiving-code-review`로 검증 후 반영
  - Finding 1 반영: `MatchResultView`에 `.id(session.workoutSessionId)` 추가 — 리매치 후 `saveState` 초기화 보장
  - Finding 2 반영 안 함: `catch` 에러 로깅은 코드베이스 전체 로깅 인프라 부재 문제로 이 PR 범위 밖

- [x] **Step 4:** 위 검증·반영이 끝나면 `superpowers:finishing-a-development-branch`로 브랜치 정리

---

## 이 단계가 검증하는 것

- 저장이 성공하면 버튼이 "저장됨"으로 바뀌고 비활성화된다.
- 저장이 실패하면 버튼이 "저장 실패, 다시 시도"로 바뀌고 계속 탭 가능 — 다시 탭하면
  `saveMatch()`가 재호출되어 재시도된다.
- 더 이상 저장 결과와 무관하게 무조건 "저장됨"을 보여주지 않는다.

> Watch에서 보낸 저장 요청(`saveFromWatch`)은 아직 `try?`로 에러를 삼킨다 — 3단계에서 고친다.
