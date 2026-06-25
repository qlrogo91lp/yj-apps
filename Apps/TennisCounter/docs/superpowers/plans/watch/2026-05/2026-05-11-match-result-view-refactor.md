# MatchResultView 리팩토링 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** MatchResultView를 스크롤 없이 한 화면에 표시되도록 리팩토링하고, 버튼을 컴포넌트로 분리하며, 툴바 백 버튼과 "재경기" 기능을 추가한다.

**Architecture:** ScrollView 제거 후 VStack 단일 레이아웃으로 변환. 버튼 3개(BackButton, SaveButton, RematchButton)를 `Result/Components/`에 분리. WorkoutSessionViewModel에 `restartMatch()` 추가.

**Tech Stack:** SwiftUI, Swift Testing (`import Testing`), watchOS

---

## 파일 구조

| 파일 | 역할 | 변경 |
|------|------|------|
| `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `restartMatch()` 함수 추가 | 수정 |
| `WatchApp/ko.lproj/Localizable.strings` | `watch_new_match` → `watch_rematch` = "재경기" | 수정 |
| `WatchApp/en.lproj/Localizable.strings` | `watch_new_match` → `watch_rematch` = "Rematch" | 수정 |
| `WatchApp/Features/Match/Result/Components/BackButton.swift` | 툴바용 백 버튼 (즉시 모드 선택 이동) | 신규 |
| `WatchApp/Features/Match/Result/Components/SaveButton.swift` | 저장 버튼 (saved 상태 분기) | 신규 |
| `WatchApp/Features/Match/Result/Components/RematchButton.swift` | 재경기 버튼 | 신규 |
| `WatchApp/Features/Match/Result/MatchResultView.swift` | ScrollView 제거, 크기 축소, 컴포넌트 교체, 모드 조건부 세트 점수 | 수정 |

---

## Task 1: restartMatch() 함수 추가

**Files:**
- Modify: `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`
- Test: `watchosTests/watchosTests.swift`

- [ ] **Step 1: 실패하는 테스트 작성**

`watchosTests/watchosTests.swift` 하단에 추가:

```swift
@Test @MainActor func testRestartMatchReusesOptions() {
    let vm = WorkoutSessionViewModel()
    let options = MatchOptions(mode: .bestOfThree, noAdRule: false, noTieRule: true)
    vm.startMatch(options: options)
    vm.finishMatch(result: .win, completedSets: [SetScore(my: 6, your: 3)])

    vm.restartMatch()

    guard case .playing(let newOptions) = vm.phase else {
        Issue.record("Expected .playing phase after restartMatch, got \(vm.phase)")
        return
    }
    #expect(newOptions.mode == .bestOfThree)
    #expect(newOptions.noAdRule == false)
    #expect(newOptions.noTieRule == true)
}
```

- [ ] **Step 2: 빌드해서 컴파일 에러 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | grep -E "error:|Build"
```

Expected: `error: value of type 'WorkoutSessionViewModel' has no member 'restartMatch'`

- [ ] **Step 3: restartMatch() 구현**

`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`의 `startNewMatch()` 함수 바로 아래에 추가:

```swift
func restartMatch() {
    guard let options = _currentSession?.options else { return }
    startMatch(options: options)
}
```

- [ ] **Step 4: 빌드 및 테스트 통과 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`

테스트는 Xcode에서 Product → Test (⌘U)로 실행 후 `testRestartMatchReusesOptions` PASS 확인.

- [ ] **Step 5: 커밋**

```bash
git add WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift watchosTests/watchosTests.swift
git commit -m "feat: WorkoutSessionViewModel에 restartMatch() 추가"
```

---

## Task 2: 로컬라이제이션 업데이트

**Files:**
- Modify: `WatchApp/ko.lproj/Localizable.strings`
- Modify: `WatchApp/en.lproj/Localizable.strings`

- [ ] **Step 1: ko.lproj 수정**

`WatchApp/ko.lproj/Localizable.strings`에서:
```
"watch_new_match" = "새 경기";
```
를 다음으로 교체:
```
"watch_rematch" = "재경기";
```

- [ ] **Step 2: en.lproj 수정**

`WatchApp/en.lproj/Localizable.strings`에서:
```
"watch_new_match" = "New Match";
```
를 다음으로 교체:
```
"watch_rematch" = "Rematch";
```

- [ ] **Step 3: 커밋**

```bash
git add WatchApp/ko.lproj/Localizable.strings WatchApp/en.lproj/Localizable.strings
git commit -m "i18n: watch_new_match 키를 watch_rematch로 교체"
```

---

## Task 3: BackButton 컴포넌트 생성

**Files:**
- Create: `WatchApp/Features/Match/Result/Components/BackButton.swift`

> 참고: `WatchApp/Features/Match/Score/Components/EarlyEndButton.swift`와 동일한 스타일 패턴.

- [ ] **Step 1: 파일 생성**

`WatchApp/Features/Match/Result/Components/BackButton.swift`:

```swift
import SwiftUI

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(.thickMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: 커밋**

```bash
git add WatchApp/Features/Match/Result/Components/BackButton.swift
git commit -m "feat: Result/Components에 BackButton 추가"
```

---

## Task 4: SaveButton 컴포넌트 생성

**Files:**
- Create: `WatchApp/Features/Match/Result/Components/SaveButton.swift`

- [ ] **Step 1: 파일 생성**

`WatchApp/Features/Match/Result/Components/SaveButton.swift`:

```swift
import SwiftUI

struct SaveButton: View {
    let saved: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: saved ? "checkmark.circle.fill" : "square.and.arrow.down")
                Text(saved ? String(localized: "result_saved") : String(localized: "result_save"))
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(saved ? .gray : .blue)
        .disabled(saved)
    }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: 커밋**

```bash
git add WatchApp/Features/Match/Result/Components/SaveButton.swift
git commit -m "feat: Result/Components에 SaveButton 추가"
```

---

## Task 5: RematchButton 컴포넌트 생성

**Files:**
- Create: `WatchApp/Features/Match/Result/Components/RematchButton.swift`

- [ ] **Step 1: 파일 생성**

`WatchApp/Features/Match/Result/Components/RematchButton.swift`:

```swift
import SwiftUI

struct RematchButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise")
                Text(String(localized: "watch_rematch"))
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green.opacity(0.8))
    }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: 커밋**

```bash
git add WatchApp/Features/Match/Result/Components/RematchButton.swift
git commit -m "feat: Result/Components에 RematchButton 추가"
```

---

## Task 6: MatchResultView 리팩토링

**Files:**
- Modify: `WatchApp/Features/Match/Result/MatchResultView.swift`

- [ ] **Step 1: MatchResultView 전체 교체**

`WatchApp/Features/Match/Result/MatchResultView.swift` 전체를 다음으로 교체:

```swift
import SwiftUI

struct MatchResultView: View {
    let session: MatchSession
    @ObservedObject var flowViewModel: WorkoutSessionViewModel
    @State private var saved = false
    @State private var saveError: String?

    var body: some View {
        VStack(spacing: 8) {
            Text(resultTitle)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(resultColor)
                .multilineTextAlignment(.center)

            if session.options.mode == .bestOfThree {
                HStack(spacing: 8) {
                    Text("\(session.mySetScore)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.green)
                    Text("-")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(session.yourSetScore)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.orange)
                }
            }

            if !session.completedSets.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(session.completedSets.enumerated()), id: \.offset) { _, set in
                        Text("\(set.my)-\(set.your)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }

            Divider().background(Color.white.opacity(0.2))

            SaveButton(saved: saved) { saveMatch() }

            RematchButton { flowViewModel.restartMatch() }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton { flowViewModel.startNewMatch() }
            }
        }
    }

    private var resultTitle: String {
        switch session.result {
        case .win: return String(localized: "watch_victory")
        case .loss: return String(localized: "watch_defeat")
        case .draw: return String(localized: "result_draw")
        case nil: return ""
        }
    }

    private var resultColor: Color {
        switch session.result {
        case .win: return .green
        case .loss: return .orange
        case .draw: return .yellow
        case nil: return .white
        }
    }

    private func saveMatch() {
        do {
            try flowViewModel.saveCurrentMatch()
            withAnimation { saved = true }
        } catch {
            saveError = error.localizedDescription
        }
    }
}

#Preview {
    let session = MatchSession(
        workoutSessionId: UUID(),
        options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false),
        kcalAtStart: 150
    )
    session.mySetScore = 1
    session.yourSetScore = 0
    session.completedSets = [SetScore(my: 6, your: 4)]
    session.endedAt = Date()
    session.result = .win
    session.kcalAtEnd = 200
    session.averageHeartRate = 145

    return MatchResultView(
        session: session,
        flowViewModel: WorkoutSessionViewModel()
    )
}
```

- [ ] **Step 2: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | grep -E "error:|BUILD"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: 커밋**

```bash
git add WatchApp/Features/Match/Result/MatchResultView.swift
git commit -m "refactor: MatchResultView ScrollView 제거 및 컴포넌트 분리"
```
