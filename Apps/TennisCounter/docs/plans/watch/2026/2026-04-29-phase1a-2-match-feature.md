# Phase 1-A ② Match Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ModeSelection 화면(One Set / Best of 3) 생성, Score 화면에 모드별 UI 분기(세트 인디케이터, 이전 세트 결과), 경기 종료 시 SwiftData에 Match 저장

**Architecture:** `ModeSelectionView` → `MatchView(format:)` 흐름. MatchViewModel이 match format을 받아 게임→세트→매치 집계 처리. 매치 종료 시 `Match` + `SetRecord` 인스턴스를 ModelContext에 삽입. iOSApp.swift의 Match 탭이 `ModeSelectionView`를 루트로 사용.

**Tech Stack:** SwiftUI NavigationStack, SwiftData ModelContext, Combine

**선행 조건:** `2026-04-29-phase1a-1-data-foundation.md` 완료 (Match/SetRecord 모델 존재)

---

## File Structure

| 파일 | 액션 | 역할 |
|------|------|------|
| `iOSApp/Features/Match/ModeSelection/ModeSelectionView.swift` | Create | 모드 선택 화면 |
| `iOSApp/Features/Match/ModeSelection/ModeSelectionViewModel.swift` | Create | 모드 선택 상태 |
| `iOSApp/Features/Match/Score/MatchViewModel.swift` | Modify | format 파라미터 + 세트 집계 + SwiftData 저장 |
| `iOSApp/Features/Match/Score/MatchView.swift` | Modify | One Set / Best of 3 UI 분기 |
| `iOSApp/Features/Match/Score/Components/CounterButtonView.swift` | Keep | 기존 유지 |
| `iOSApp/iOSApp.swift` | Modify | Match 탭 → ModeSelectionView로 교체 |

---

### Task 1: MatchFormat enum

**Files:**
- Create: `Shared/Models/MatchFormat.swift`

> MatchFormat은 iOS와 Watch 양쪽에서 참조하므로 Shared/Models에 둔다.

- [ ] **Step 1: MatchFormat.swift 생성**

```swift
import Foundation

enum MatchFormat: String, CaseIterable {
    case oneSet = "one_set"
    case bestOfThree = "best_of_3"

    var localizedTitle: String {
        switch self {
        case .oneSet: return String(localized: "match_format_one_set")
        case .bestOfThree: return String(localized: "match_format_best_of_3")
        }
    }

    var localizedDescription: String {
        switch self {
        case .oneSet: return String(localized: "match_format_one_set_desc")
        case .bestOfThree: return String(localized: "match_format_best_of_3_desc")
        }
    }

    var setsToWin: Int {
        switch self {
        case .oneSet: return 1
        case .bestOfThree: return 2
        }
    }
}
```

- [ ] **Step 2: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋**

```bash
git add Shared/Models/MatchFormat.swift
git commit -m "feat: add MatchFormat enum"
```

---

### Task 2: ModeSelectionViewModel

**Files:**
- Create: `iOSApp/Features/Match/ModeSelection/ModeSelectionViewModel.swift`

- [ ] **Step 1: 디렉터리 생성**

```bash
mkdir -p iOSApp/Features/Match/ModeSelection
```

- [ ] **Step 2: ModeSelectionViewModel.swift 생성**

```swift
import SwiftUI

@MainActor
final class ModeSelectionViewModel: ObservableObject {
    @Published var selectedFormat: MatchFormat?

    func selectFormat(_ format: MatchFormat) {
        selectedFormat = format
    }
}
```

- [ ] **Step 3: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

---

### Task 3: ModeSelectionView

**Files:**
- Create: `iOSApp/Features/Match/ModeSelection/ModeSelectionView.swift`

- [ ] **Step 1: ModeSelectionView.swift 생성**

```swift
import SwiftUI

struct ModeSelectionView: View {
    @StateObject private var viewModel = ModeSelectionViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 24) {
                    Text(String(localized: "new_match"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    ForEach(MatchFormat.allCases, id: \.rawValue) { format in
                        NavigationLink(value: format) {
                            ModeCardView(format: format)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
            }
            .navigationDestination(for: MatchFormat.self) { format in
                MatchView(format: format)
            }
            .navigationBarHidden(true)
        }
    }
}

private struct ModeCardView: View {
    let format: MatchFormat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(format == .oneSet ? "🎾" : "🏆")
                    .font(.system(size: 28))
                Text(format.localizedTitle)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
            }
            Text(format.localizedDescription)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(20)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ModeSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        ModeSelectionView()
    }
}
```

- [ ] **Step 2: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋**

```bash
git add iOSApp/Features/Match/ModeSelection/
git commit -m "feat: add ModeSelectionView and ModeSelectionViewModel"
```

---

### Task 4: MatchViewModel 리팩터링 (세트 집계 + SwiftData 저장)

**Files:**
- Modify: `iOSApp/Features/Match/Score/MatchViewModel.swift`

> 현재 MatchViewModel은 format 개념이 없고 myGameScore/yourGameScore만 관리. 세트 집계와 SwiftData 저장 로직을 추가한다.

- [ ] **Step 1: MatchViewModel.swift 전체 교체**

```swift
import Combine
import SwiftData
import SwiftUI

@MainActor
final class MatchViewModel: ObservableObject {
    let format: MatchFormat

    @Published var score = Score()
    @Published var myGameScore: Int = 0
    @Published var yourGameScore: Int = 0
    @Published var mySetScore: Int = 0
    @Published var yourSetScore: Int = 0
    @Published var currentSetNumber: Int = 1
    @Published var completedSets: [(my: Int, your: Int)] = []
    @Published var isMatchOver: Bool = false
    @Published var didWin: Bool = false

    private var cancellable: AnyCancellable?
    private var modelContext: ModelContext?

    init(format: MatchFormat = .oneSet, modelContext: ModelContext? = nil) {
        self.format = format
        self.modelContext = modelContext
        cancellable = score.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func confirmScore() {
        guard score.myScore != score.yourScore else { return }

        if score.myScore == 50 {
            myGameScore += 1
            score.resetData()
            checkSetUpdate()
        } else if score.yourScore == 50 {
            yourGameScore += 1
            score.resetData()
            checkSetUpdate()
        }
    }

    func resetAll() {
        myGameScore = 0
        yourGameScore = 0
        mySetScore = 0
        yourSetScore = 0
        currentSetNumber = 1
        completedSets = []
        isMatchOver = false
        didWin = false
        score.resetData()
    }

    // MARK: - Private

    private func checkSetUpdate() {
        guard isSetComplete() else { return }

        let myWonSet = myGameScore > yourGameScore
        completedSets.append((my: myGameScore, your: yourGameScore))

        if myWonSet {
            mySetScore += 1
        } else {
            yourSetScore += 1
        }

        myGameScore = 0
        yourGameScore = 0
        currentSetNumber += 1

        if mySetScore >= format.setsToWin {
            didWin = true
            isMatchOver = true
            saveMatch()
        } else if yourSetScore >= format.setsToWin {
            didWin = false
            isMatchOver = true
            saveMatch()
        }
    }

    private func isSetComplete() -> Bool {
        let maxGames = max(myGameScore, yourGameScore)
        let minGames = min(myGameScore, yourGameScore)
        return maxGames >= 6 && (maxGames - minGames) >= 2
    }

    private func saveMatch() {
        guard let context = modelContext else { return }

        let match = Match(matchFormat: format.rawValue)
        match.endedAt = Date()
        match.myTotalSets = mySetScore
        match.yourTotalSets = yourSetScore
        match.isCompleted = true

        let setRecords = completedSets.enumerated().map { index, result in
            SetRecord(myGames: result.my, yourGames: result.your, setNumber: index + 1)
        }
        match.sets = setRecords

        context.insert(match)
        try? context.save()
    }
}
```

- [ ] **Step 2: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋**

```bash
git add iOSApp/Features/Match/Score/MatchViewModel.swift
git commit -m "feat: MatchViewModel supports set aggregation and SwiftData save"
```

---

### Task 5: MatchView 업데이트 (모드별 UI 분기)

**Files:**
- Modify: `iOSApp/Features/Match/Score/MatchView.swift`

- [ ] **Step 1: MatchView.swift 전체 교체**

```swift
import SwiftData
import SwiftUI

struct MatchView: View {
    let format: MatchFormat

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MatchViewModel

    init(format: MatchFormat) {
        self.format = format
        _viewModel = StateObject(wrappedValue: MatchViewModel(format: format))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isMatchOver {
                matchOverView
            } else {
                VStack(spacing: 0) {
                    headerView
                    if format == .bestOfThree {
                        setHistoryBar
                    }
                    scoreInputView
                    confirmButton
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.injectContext(modelContext)
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            if format == .bestOfThree {
                Text(String(format: String(localized: "set_indicator_format"), viewModel.currentSetNumber))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }

            Text("\(viewModel.myGameScore)")
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(.green)

            Text(":")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)

            Text("\(viewModel.yourGameScore)")
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(.orange)

            Spacer()

            Button(action: { viewModel.resetAll() }) {
                Text(String(localized: "btn_reset"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.borderless)
        }
        .padding(.bottom, 8)
    }

    private var setHistoryBar: some View {
        HStack(spacing: 16) {
            ForEach(viewModel.completedSets.indices, id: \.self) { idx in
                let set = viewModel.completedSets[idx]
                HStack(spacing: 4) {
                    Text("\(set.my)")
                        .foregroundColor(.green)
                    Text("-")
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(set.your)")
                        .foregroundColor(.orange)
                }
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
            Spacer()

            HStack(spacing: 8) {
                Text("\(viewModel.mySetScore)")
                    .foregroundColor(.green)
                    .font(.system(size: 18, weight: .bold))
                Text(String(localized: "set_indicator_format").replacingOccurrences(of: "%d", with: ""))
                    .foregroundColor(.white.opacity(0.5))
                    .font(.system(size: 14))
                Text("\(viewModel.yourSetScore)")
                    .foregroundColor(.orange)
                    .font(.system(size: 18, weight: .bold))
            }
        }
        .padding(.vertical, 8)
    }

    private var scoreInputView: some View {
        HStack {
            CounterButtonView(flag: 0, score: viewModel.score)
            Spacer()
            Text(":")
                .font(.system(size: 25, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            CounterButtonView(flag: 1, score: viewModel.score)
        }
        .padding(.vertical)
    }

    private var confirmButton: some View {
        Button(action: { viewModel.confirmScore() }) {
            Text(String(localized: "btn_confirm"))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.blue)
        }
    }

    private var matchOverView: some View {
        VStack(spacing: 20) {
            Text(viewModel.didWin
                 ? String(localized: "match_over_win")
                 : String(localized: "match_over_lose"))
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(viewModel.didWin ? .green : .orange)

            HStack(spacing: 24) {
                ForEach(viewModel.completedSets.indices, id: \.self) { idx in
                    let set = viewModel.completedSets[idx]
                    VStack(spacing: 2) {
                        Text("Set \(idx + 1)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                        HStack(spacing: 4) {
                            Text("\(set.my)").foregroundColor(.green)
                            Text("-").foregroundColor(.white.opacity(0.5))
                            Text("\(set.your)").foregroundColor(.orange)
                        }
                        .font(.system(size: 18, weight: .bold))
                    }
                }
            }

            Button(action: {
                viewModel.resetAll()
                dismiss()
            }) {
                Text(String(localized: "btn_new_match"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
        }
        .padding()
    }
}

struct MatchView_Previews: PreviewProvider {
    static var previews: some View {
        MatchView(format: .bestOfThree)
    }
}
```

- [ ] **Step 2: MatchViewModel에 injectContext 메서드 추가**

`iOSApp/Features/Match/Score/MatchViewModel.swift`에서 `init` 아래에 추가:

```swift
func injectContext(_ context: ModelContext) {
    self.modelContext = context
}
```

기존 `init`의 `modelContext` 파라미터는 유지 (Watch에서도 호환).

- [ ] **Step 3: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: 커밋**

```bash
git add iOSApp/Features/Match/Score/MatchView.swift \
        iOSApp/Features/Match/Score/MatchViewModel.swift
git commit -m "feat: MatchView supports One Set / Best of 3 UI branching"
```

---

### Task 6: iOSApp.swift Match 탭 연결

**Files:**
- Modify: `iOSApp/iOSApp.swift`

> Match 탭의 placeholder `Text("Match")`를 `ModeSelectionView()`로 교체한다.

- [ ] **Step 1: iOSApp.swift 수정**

`iOSApp/iOSApp.swift`의 Match 탭 부분 교체:

```swift
// 기존
NavigationStack {
    Text("Match")
}
.tabItem {
    Label(String(localized: "tab_match"), systemImage: "sportscourt.fill")
}

// 교체 후
ModeSelectionView()
    .tabItem {
        Label(String(localized: "tab_match"), systemImage: "sportscourt.fill")
    }
```

- [ ] **Step 2: iOS 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj \
  -scheme "TennisCounter" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 시뮬레이터 스모크 테스트**

Xcode 시뮬레이터에서:
1. 앱 실행 → Match 탭 확인
2. "One Set" 선택 → Score 화면 진입 확인
3. 점수 입력 후 Confirm → 게임 점수 증가 확인
4. "Best of 3" 선택 → 세트 인디케이터 표시 확인

- [ ] **Step 4: 커밋**

```bash
git add iOSApp/iOSApp.swift
git commit -m "feat: connect ModeSelectionView to Match tab"
```

---

## 완료 기준

- [x] Match 탭 진입 시 One Set / Best of 3 선택 화면이 표시됨
- [x] One Set 선택 → Score 화면 (세트 인디케이터 없음)
- [x] Best of 3 선택 → Score 화면 (세트 인디케이터 + 이전 세트 결과 표시)
- [x] 세트 완료(6게임 이상, 2게임 차) 시 다음 세트로 자동 전환
- [x] 매치 완료 시 결과 화면 표시 + SwiftData에 Match 저장
- [x] iOS/Watch 빌드 모두 성공
