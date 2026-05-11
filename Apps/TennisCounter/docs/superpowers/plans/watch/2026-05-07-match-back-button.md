# MatchView 백 버튼 네비게이션 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** MatchView에 네비게이션 백 버튼을 추가하여 언제든 모드 선택으로 돌아갈 수 있도록 하고, EarlyEndButton을 제거합니다.

**Architecture:** 
- MatchViewModel에서 조건부 표시 로직(showEarlyEndButton, updateEarlyEndVisibility) 제거
- MatchView에 백 버튼 UI 추가 (좌측 상단, NavigationBackButton 스타일)
- 경기 중일 때만 확인 다이얼로그 표시, 경기 전이면 바로 모드 선택으로 복귀
- EarlyEndButton 컴포넌트 파일 삭제 및 라벨 업데이트

**Tech Stack:** SwiftUI, MVVM

---

## Task 1: MatchViewModel에서 EarlyEndButton 관련 코드 제거

**Files:**
- Modify: `WatchApp/Features/Match/MatchViewModel.swift`

- [ ] **Step 1: MatchViewModel.swift 열기**

파일을 읽어 현재 상태 확인:
```bash
cat WatchApp/Features/Match/MatchViewModel.swift
```

- [ ] **Step 2: showEarlyEndButton 속성 제거**

라인 11의 `@Published var showEarlyEndButton: Bool = false` 제거:

```swift
class MatchViewModel: ObservableObject {
    @Published var score = Score()
    @Published var myGameScore: Int = 0
    @Published var yourGameScore: Int = 0
    @Published var mySetScore: Int = 0
    @Published var yourSetScore: Int = 0
    @Published var completedSets: [SetScore] = []
    // showEarlyEndButton 제거됨

    let options: MatchOptions
    var onMatchFinished: ((MatchResult, [SetScore]) -> Void)?
```

- [ ] **Step 3: updateEarlyEndVisibility() 메서드 제거**

라인 87-90의 메서드 제거:
```swift
// 제거:
// private func updateEarlyEndVisibility() {
//     guard options.mode == .oneSet else { showEarlyEndButton = false; return }
//     showEarlyEndButton = myGameScore >= 5 && yourGameScore >= 5
// }
```

- [ ] **Step 4: addPoint 메서드에서 updateEarlyEndVisibility() 호출 제거**

라인 35의 `updateEarlyEndVisibility()` 호출 제거:

```swift
func addPoint(_ side: PlayerSide) {
    guard score.addPoint(side) != nil else { return }
    withAnimation(.bouncy) {
        if side == .me { myGameScore += 1 } else { yourGameScore += 1 }
    }
    score.reset()
    checkSetUpdate()
    // updateEarlyEndVisibility() 제거됨
}
```

- [ ] **Step 5: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | grep -E "error:|warning:|Build complete"
```

Expected: "Build complete"

- [ ] **Step 6: Commit**

```bash
git add WatchApp/Features/Match/MatchViewModel.swift
git commit -m "refactor: MatchViewModel에서 showEarlyEndButton 관련 코드 제거"
```

---

## Task 2: MatchView에 백 버튼 추가 및 다이얼로그 로직 구현

**Files:**
- Modify: `WatchApp/Features/Match/MatchView.swift`

- [ ] **Step 1: showEndConfirm state 추가**

라인 7에 새로운 state 추가:

```swift
struct MatchView: View {
    let options: MatchOptions
    @ObservedObject var flowViewModel: WorkoutFlowViewModel
    @StateObject private var viewModel: MatchViewModel
    @State private var showEarlyEndConfirm = false
    @State private var showEndConfirm = false  // 추가

    init(options: MatchOptions, flowViewModel: WorkoutFlowViewModel) {
```

- [ ] **Step 2: ZStack에 백 버튼 추가**

ZStack의 VStack 위에 백 버튼 추가:

```swift
var body: some View {
    ZStack {
        // Score pad
        HStack(spacing: 0) {
            PlayerScoreButton(
                displayScore: viewModel.score.myDisplayScore,
                player: String(localized: "watch_score_me"),
                color: .green,
                action: { viewModel.addPoint(.me) }
            )

            PlayerScoreButton(
                displayScore: viewModel.score.yourDisplayScore,
                player: String(localized: "watch_score_opp"),
                color: .orange,
                action: { viewModel.addPoint(.opponent) }
            )
        }
        .ignoresSafeArea()

        VStack {
            // Back button
            HStack {
                Button(action: handleBackButtonTap) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(.top, 12)
            .padding(.horizontal, 12)

            // Header row: GameScore + SetScore
            HStack(alignment: .top) {
```

- [ ] **Step 3: 백 버튼 탭 핸들러 메서드 추가**

`body` 아래에 메서드 추가:

```swift
    }

    private func handleBackButtonTap() {
        if viewModel.myGameScore > 0 || viewModel.yourGameScore > 0 {
            showEndConfirm = true
        } else {
            flowViewModel.finishMatch(result: .draw, completedSets: viewModel.completedSets)
        }
    }
}
```

- [ ] **Step 4: 기존 EarlyEndButton 제거**

라인 53-56의 EarlyEndButton 제거:

```swift
// 제거할 부분:
// if viewModel.showEarlyEndButton {
//     EarlyEndButton { showEarlyEndConfirm = true }
//         .padding(.top, 4)
// }
```

수정된 HStack:

```swift
            // Header row: GameScore + SetScore
            HStack(alignment: .top) {
                Spacer()
                VStack(spacing: 4) {
                    GameScore(
                        myGameScore: viewModel.myGameScore,
                        yourGameScore: viewModel.yourGameScore,
                        isTieBreak: viewModel.score.gameMode == .tieBreak
                    )

                    SetScore(
                        mySetScore: viewModel.mySetScore,
                        yourSetScore: viewModel.yourSetScore
                    )
                }
                Spacer()
            }
            .padding(.top, 20)
            .padding(.horizontal, 8)
```

- [ ] **Step 5: 새로운 confirmationDialog 추가 (showEarlyEndConfirm 아래)**

라인 92의 기존 confirmationDialog 아래에 추가:

```swift
        .confirmationDialog(
            String(localized: "early_end_confirm_title"),
            isPresented: $showEarlyEndConfirm
        ) {
            Button(String(localized: "early_end_confirm_yes"), role: .destructive) {
                viewModel.triggerEarlyEnd()
            }
        } message: {
            Text(String(localized: "early_end_confirm_message"))
        }
        .confirmationDialog(
            String(localized: "end_match_confirm_title"),
            isPresented: $showEndConfirm
        ) {
            Button(String(localized: "end_match_confirm_yes"), role: .destructive) {
                flowViewModel.finishMatch(result: .draw, completedSets: viewModel.completedSets)
            }
        } message: {
            Text(String(localized: "end_match_confirm_message"))
        }
```

- [ ] **Step 6: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | grep -E "error:|warning:|Build complete"
```

Expected: "Build complete"

- [ ] **Step 7: Commit**

```bash
git add WatchApp/Features/Match/MatchView.swift
git commit -m "feat: 백 버튼으로 경기 제어 기능 추가"
```

---

## Task 3: 라벨 업데이트 및 EarlyEndButton 파일 제거

**Files:**
- Modify: `WatchApp/ko.lproj/Localizable.strings`
- Delete: `WatchApp/Features/Match/Components/EarlyEndButton.swift`

- [ ] **Step 1: Localizable.strings 업데이트**

기존 라벨 변경 및 새 라벨 추가:

```
"watch_quick_match" = "빠른 경기";
"watch_score_me" = "나";
"watch_score_opp" = "상대";
"watch_undo" = "되돌리기";
"watch_new_match" = "새 경기";
"watch_victory" = "승리!";
"watch_defeat" = "패배";
"watch_set_label" = "세트";
"watch_start_workout" = "운동 시작";
"workout_pause" = "일시정지";
"workout_resume" = "재개";
"workout_end" = "운동 종료";
"metrics_elapsed" = "경과 시간";
"metrics_paused" = "일시정지";
"metrics_kcal" = "kcal";
"metrics_bpm" = "BPM";
"mode_select_title" = "모드 선택";
"mode_one_set" = "1 세트 경기";
"mode_one_set_desc" = "단판 경기";
"mode_best_of_3" = "3세트 경기";
"mode_best_of_3_desc" = "2세트 선취";
"mode_no_ad" = "No-Ad";
"mode_no_tie" = "No Tiebreak";
"set_tiebreak" = "TIE";
"score_deciding_point" = "매치 포인트";
"early_end_confirm_title" = "경기 종료";
"early_end_confirm_message" = "매치를 무승부로 종료할까요?";
"early_end_confirm_yes" = "무승부";
"end_match_confirm_title" = "경기를 종료하시겠습니까?";
"end_match_confirm_message" = "진행 중인 경기를 종료합니다.";
"end_match_confirm_yes" = "종료";
"result_save" = "저장";
"result_saved" = "저장됨";
"result_draw" = "무승부";
```

- [ ] **Step 2: EarlyEndButton.swift 파일 삭제**

```bash
rm WatchApp/Features/Match/Components/EarlyEndButton.swift
```

확인:
```bash
ls -la WatchApp/Features/Match/Components/EarlyEndButton.swift 2>&1
```

Expected: "No such file or directory"

- [ ] **Step 3: 빌드 확인**

```bash
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter Watch App" -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build 2>&1 | grep -E "error:|warning:|Build complete"
```

Expected: "Build complete" (EarlyEndButton 사용처가 없으므로 에러 없음)

- [ ] **Step 4: Commit**

```bash
git add WatchApp/ko.lproj/Localizable.strings
git rm WatchApp/Features/Match/Components/EarlyEndButton.swift
git commit -m "refactor: EarlyEndButton 제거 및 라벨 업데이트"
```

---

## 검증

작업 완료 후 다음을 확인하세요:

1. **빌드 성공:** 경고나 에러 없이 빌드 완료
2. **코드 검토:** 변경사항이 설계 문서와 일치
3. **UI 테스트:** Watch 시뮬레이터에서
   - 경기 시작 전: 백 버튼 탭 → 다이얼로그 없이 모드 선택으로 이동
   - 경기 중: 백 버튼 탭 → "경기를 종료하시겠습니까?" 다이얼로그 표시
   - 다이얼로그 취소: MatchView 유지
   - 다이얼로그 종료: 모드 선택으로 복귀, 운동 세션 계속 진행
