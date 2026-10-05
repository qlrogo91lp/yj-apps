# 매치 화면의 WorkoutSessionViewModel 의존 끊기 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `Match/` 화면들이 `WorkoutSessionViewModel` 을 통째로 받아 WorkoutSession ↔ Match 가 서로를 아는 순환 의존을 끊는다. VM 을 아는 곳은 부모 `WorkoutSessionView` 한 곳으로 모은다.

**Architecture:** 데이터는 아래로, 이벤트는 위로. Match 화면은 보여줄 **값**과 사용자 행동을 알릴 **콜백**만 받고, 그 콜백을 VM 메서드에 잇는 일은 부모가 한다.
iOS `ScoreView`(`isDriver` + `onMatchFinished`)와 `SaveButton`(`state` + `action`)이 이미 이 방식이라, 같은 관계를 한 단계 위로 올리는 작업이다.
VM 로직·테스트는 바꾸지 않는다. WorkoutSession → Match 한 방향(VM 이 `ScoreViewModel` 소유, 부모가 Match 화면 조합)은 부모→자식이라 남긴다.

**Tech Stack:** SwiftUI, Swift Testing

**배경:** Notion "Feature 폴더 구조 재정비 아이디어 (WorkoutSession · Match)" (2026-10-02 논의) 의 **B안**. 폴더 이동(A안)과 `MatchFlowView` 분리는 이 플랜의 범위가 아니다 — 의존이 끊긴 뒤 별도로 판단한다.

## Global Constraints

- **VM 은 손대지 않는다.** 권한 규칙(`startNewMatch` 의 `isDriver` 가드 등)은 VM 안에 있어 화면이 VM 을 몰라도 그대로 지켜진다
- **상위 흐름 VM 만 끊는다.** 각 화면 자기 몫의 VM(`ScoreViewModel`, `ModeViewModel`)은 그대로 받는다
- **View 는 테스트하지 않는다** (앱 `CLAUDE.md` Testing). 기존 VM 테스트 통과 + 수동 확인이 검증 수단이다
- 파일 생성·삭제 없음 — Xcode GUI 작업 없음
- 브랜치 `refactor/ralli-match-view-deps`, 플랫폼별 커밋 2개 → PR

## 시그니처 변경

| 화면 | 이전 | 이후 |
|---|---|---|
| ModeView (Watch·iOS) | `viewModel: WorkoutSessionViewModel` | `onStart: (MatchOptions) -> Void` |
| ScoreView (Watch) | `flowViewModel: WorkoutSessionViewModel` | `isDriver: Bool`, `onExit: () -> Void` |
| MatchResultView (Watch) | `flowViewModel: WorkoutSessionViewModel` | `saveState: SaveButtonState`, `onSave`, `onRematch`, `onBack` |
| MatchResultView (iOS) | `viewModel: WorkoutSessionViewModel` | `onSave: () -> Bool`, `onRematch` |
| ScoreView (iOS) | (이미 값과 콜백) | 변경 없음 |

**결정 사항**

- **Watch `SaveAckState` → `SaveButtonState` 변환은 부모로 옮긴다.** `SaveAckState` 는 VM 안에 중첩된 타입이라 화면에 두면 의존이 남는다
- **iOS `onSave` 는 `Bool` 을 돌려준다.** `saveCurrentMatch() -> Match?` 결과로 저장 성공·실패를 즉시 표시하기 때문이다
- **Watch `ScoreView` 는 `canScore` 가 아니라 `isDriver` 를 받고, 크라운 가드의 `phase` 검사를 뺀다.**
  그 검사는 크라운 한 번에 여러 점이 들어가던 초기 구현(`0d8d518`)에서 반복 도중 경기가 끝나면 멈추려던 것이다.
  지금은 `CrownPointGate` 가 한 번 돌리기에 1점만 허용하고, `ScoreView` 는 `.playing` 에서만 존재하며, 점수 버튼에는 원래 `phase` 가드가 없었다.
  iOS `ScoreView` 와 이름도 맞는다

## Task 1: Watch

**Files:**
- Modify: `WatchApp/Features/Match/Mode/ModeView.swift`
- Modify: `WatchApp/Features/Match/Score/ScoreView.swift`
- Modify: `WatchApp/Features/Match/Result/MatchResultView.swift`
- Modify: `WatchApp/Features/WorkoutSession/WorkoutSessionView.swift`

- [x] **Step 1:** `ModeView` — `viewModel` 을 `onStart` 로, 두 `ModeOptionItem` 의 `startMatch` 호출을 `onStart(selectionVM.options)` 로
- [x] **Step 2:** `ScoreView` — `flowViewModel` 을 `isDriver`·`onExit` 로. 점수 버튼·크라운·MirrorBadge·뒤로가기 툴바의 `flowViewModel.isDriver` 를 `isDriver` 로, `startNewMatch()` 두 곳을 `onExit()` 로. 크라운 가드는 `guard isDriver else { return }`. 프리뷰 갱신
- [x] **Step 3:** `MatchResultView` — `flowViewModel` 을 `saveState`·`onSave`·`onRematch`·`onBack` 으로. `buttonState` 프로퍼티 제거. 프리뷰 갱신
- [x] **Step 4:** `WorkoutSessionView.centerView` 에서 연결

```swift
case .modeSelection:
    ModeView(onStart: { viewModel.startMatch(options: $0) })
case .playing:
    ScoreView(
        viewModel: viewModel.scoreVM,
        isDriver: viewModel.isDriver,
        onExit: { viewModel.startNewMatch() }
    )
case let .finished(session):
    MatchResultView(
        session: session,
        saveState: saveButtonState,
        onSave: { viewModel.saveCurrentMatch() },
        onRematch: { viewModel.restartMatch() },
        onBack: { viewModel.startNewMatch() }
    )
```

  `saveButtonState` 는 `MatchResultView` 에서 옮겨 온 변환을 private 프로퍼티로 둔다

- [x] **Step 5:** `grep -rn 'WorkoutSessionViewModel\|flowViewModel' WatchApp/Features/Match` 결과가 비어 있는지 확인
- [x] **Step 6:** Watch 빌드 + `RalliWatchTests` → 커밋 `♻️ 워치 매치 화면이 WorkoutSessionViewModel 대신 값과 콜백을 받는다`

## Task 2: iOS

**Files:**
- Modify: `iOSApp/Features/Match/Mode/ModeView.swift`
- Modify: `iOSApp/Features/Match/Result/MatchResultView.swift`
- Modify: `iOSApp/Features/WorkoutSession/WorkoutSessionView.swift`

- [x] **Step 1:** `ModeView` — `viewModel` 을 `onStart` 로. 프리뷰 `ModeView(onStart: { _ in })`
- [x] **Step 2:** `MatchResultView` — `viewModel` 을 `onSave: () -> Bool`·`onRematch` 로. `saveMatch()` 는 `saveState = onSave() ? .saved : .failed`. 프리뷰 갱신
- [x] **Step 3:** `WorkoutSessionView.scoreTabContent` 에서 연결 — `onSave: { viewModel.saveCurrentMatch() != nil }`. `.id(session.workoutSessionId)` 는 유지
- [x] **Step 4:** `grep -rn 'WorkoutSessionViewModel' iOSApp/Features/Match` 결과가 비어 있는지 확인
- [x] **Step 5:** iOS 빌드 + `RalliTests` → 커밋 `♻️ iOS 매치 화면이 WorkoutSessionViewModel 대신 값과 콜백을 받는다`

## Task 3: 검증 · PR

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')

make lint && make format
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" -only-testing:RalliWatchTests test
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" -only-testing:RalliTests test
```

- [x] **Step 1:** lint·format·빌드·테스트
- [x] **Step 2:** PR 생성 — 머지는 수동 확인 후
- [ ] **Step 3:** 수동 확인 (시뮬레이터 또는 실기기)
  - 모드 선택 → 경기 → 결과 → 저장 / 재경기 / 뒤로가기 (Watch·iOS)
  - Watch 저장 버튼의 대기 → 완료/실패 표시
  - mirror 기기에서 점수 입력(버튼·크라운), undo, 뒤로가기가 막히는지
- [ ] **Step 4:** `gh pr merge 37 --merge --delete-branch`, 루트 `TODO.md` 행 취소선

## 실행 기록

플랜 문서보다 구현이 먼저 진행됐다 (2026-10-06, 대화 안에서 승인한 플랜을 실행). 이 문서는 그 플랜과 실행 결과를 사후에 남긴 것이다.

- **PR:** [#37](https://github.com/qlrogo91lp/yj-apps/pull/37) — 커밋 `1cf6c8e`(Watch) · `3cec469`(iOS)
- **lint·format:** 위반 0건
- **Watch:** 빌드 성공, `RalliWatchTests` 93개 통과
- **iOS:** 빌드 성공. `RalliTests` 는 테스트 호스트가 `NSInternalInconsistencyException: No eligible connection available` 로 크래시한다.
  변경을 stash 한 main 코드에서도 같은 조건으로 재현됐다 (전체 실행 1회, `WorkoutSessionViewModelTests` 단독 2회) — 이 플랜과 무관한 기존 문제다.
  루트 `TODO.md` 의 "`saveFromWatchPersistsMatch` 테스트 오염 수정" 항목이 다룬다
- **플랜 대비 변경:** Watch `ScoreView` 의 입력을 `canScore` 에서 `isDriver` 로 바꿨다 (위 결정 사항)
