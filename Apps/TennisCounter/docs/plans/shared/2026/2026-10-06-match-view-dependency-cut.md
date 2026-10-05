# 매치 화면의 WorkoutSessionViewModel 의존 끊기 · 폴더 재배치 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `Match/` 화면들이 `WorkoutSessionViewModel` 을 통째로 받아 WorkoutSession ↔ Match 가 서로를 아는 순환 의존을 끊고(1단계),
`Match/` 를 `WorkoutSession/` 아래로 옮겨 상태 소유자와 폴더 경계를 맞춘다(2단계).

**Architecture:** 데이터는 아래로, 이벤트는 위로. Match 화면은 보여줄 **값**과 사용자 행동을 알릴 **콜백**만 받고, 그 콜백을 VM 메서드에 잇는 일은 부모가 한다.
iOS `ScoreView`(`isDriver` + `onMatchFinished`)와 `SaveButton`(`state` + `action`)이 이미 이 방식이라, 같은 관계를 한 단계 위로 올리는 작업이다.
그 뒤 Match 를 WorkoutSession 의 하위 흐름으로 옮겨, WorkoutSession 이 Match 를 조합하고 `ScoreViewModel` 을 소유하는 것이 같은 Feature 안의 일이 되게 한다.

**Tech Stack:** SwiftUI, Swift Testing

**배경:** Notion "Feature 폴더 구조 재정비 아이디어 (WorkoutSession · Match)" (2026-10-02 논의). 1단계가 **B안**, 2단계가 **A안**이다.
`MatchFlowView` 분리는 두 단계 모두 범위 밖이다.

| 단계 | 내용 | 상태 |
|---|---|---|
| 1단계 | 의존 끊기 (B안) — 화면 시그니처를 값과 콜백으로 | **완료** ([PR #37](https://github.com/qlrogo91lp/yj-apps/pull/37)) · 수동 확인 대기 |
| 2단계 | 폴더 이동 (A안) — `Match/` → `WorkoutSession/Match/` | 실행 대기 |

---

# 1단계 — 의존 끊기 (B안, 완료)

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
- [x] **Step 4:** `gh pr merge 37 --merge --delete-branch`, 루트 `TODO.md` 행 취소선

## 1단계 실행 기록

플랜 문서보다 구현이 먼저 진행됐다 (2026-10-06, 대화 안에서 승인한 플랜을 실행). 이 단계는 그 플랜과 실행 결과를 사후에 남긴 것이다.

- **PR:** [#37](https://github.com/qlrogo91lp/yj-apps/pull/37) — 머지 `9a3133e`. 커밋 `8630005`(Watch) · `1936ffd`(iOS)
- **lint·format:** 위반 0건
- **Watch:** 빌드 성공, `RalliWatchTests` 93개 통과
- **iOS:** 빌드 성공. 처음 실행에서 `RalliTests` 는 테스트 호스트가 `NSInternalInconsistencyException: No eligible connection available` 로 크래시했다.
  변경을 stash 한 main 코드에서도 같은 조건으로 재현됐다 (전체 실행 1회, `WorkoutSessionViewModelTests` 단독 2회) — 이 플랜과 무관한 기존 문제였다
- **PR #38(테스트 저장소 격리) 머지 후 재검증:** 브랜치를 main(`7b7d7de`) 위로 rebase 하고 기본 병렬로 `RalliTests` 전체를 두 번 —
  두 번 모두 224개 통과, 실패 0, `No eligible` 0건. `RalliWatchTests` 93개 통과, lint·format 위반 0건
- **수동 확인(Task 3 Step 3)은 머지 시점까지 하지 않았다** — 머지 후 별도로 확인한다
- **플랜 대비 변경:** Watch `ScoreView` 의 입력을 `canScore` 에서 `isDriver` 로 바꿨다 (위 결정 사항)
- **같은 PR 에 규칙 추가:** 루트 `CLAUDE.md` 앱 코드 컨벤션에 "ViewModel 전달 (단방향)" 절

---

# 2단계 — 폴더 이동 (A안)

## 왜 이어서 하나

1단계로 Match 화면이 WorkoutSession 의 VM 을 붙잡는 방향은 끊겼지만, 두 폴더는 여전히 형제 Feature 라 루트 `CLAUDE.md` 와 두 군데가 어긋난다.

1. **Import 규칙 "Feature → Shared만 import 가능"** — WorkoutSession 이 Match 화면을 조합하고 `ScoreViewModel` 을 소유하는 것은 Feature 간 참조다
2. **"ViewModel 전달" 절의 "ViewModel 은 자기 Feature 안에서만 쓴다"** — `WorkoutSessionViewModel` 이 다른 Feature 의 `ScoreViewModel` 을 만들고 콜백을 잇는다

Match 를 WorkoutSession 밖에서 쓸 계획이 없으므로(Notion 의 A/B 판단 기준) Match 는 WorkoutSession 의 하위 흐름이다.
폴더를 그 관계에 맞추면 두 항목 모두 같은 Feature 안의 일이 된다.

## Global Constraints

- **코드 변경 없음.** 앱은 단일 모듈이라 폴더를 옮겨도 import 문이 없고 빌드 대상도 그대로다
- **이동은 `git mv` (파일시스템).** `Match/` 는 동기화 루트(`iOSApp`·`WatchApp`·`iosTests`·`watchosTests`) 안의 일반 폴더라
  `project.pbxproj` 에 경로·예외 항목이 없다 (`grep -c Match project.pbxproj` = 0).
  루트 `CLAUDE.md` 의 "폴더 rename 은 Xcode 네비게이터에서" 는 pbxproj 에 `path` 가 남는 폴더 얘기라 해당하지 않는다. 이동 후 `project.pbxproj` diff 가 비어 있는지 확인한다
- **테스트 폴더도 소스 구조를 그대로 미러링한다** (앱 `CLAUDE.md` Testing)
- **살아 있는 문서만 고친다.** 과거 플랜·로그 문서의 옛 경로는 그 시점의 기록이라 그대로 둔다
- `MatchFlowView` 분리는 범위 밖
- 브랜치 `refactor/ralli-match-folder-move` (`origin/main` 에서 분기) → PR → 머지는 확인 후

## 목표 구조

```
iOSApp/Features/WorkoutSession/            WatchApp/Features/WorkoutSession/
├── WorkoutSessionView.swift               ├── WorkoutSessionView.swift
├── WorkoutSessionViewModel.swift          ├── WorkoutSessionViewModel.swift
├── README.md                              ├── WorkoutConfiguration+Tennis.swift
├── Components/                            ├── README.md
│   └── WorkoutIndicator.swift             └── Match/
└── Match/                                     ├── Mode/
    ├── Mode/                                  ├── Score/
    ├── Score/                                 └── Result/
    └── Result/

iosTests/WorkoutSession/                   watchosTests/WorkoutSession/
├── SessionRecordSavingTests.swift         ├── WorkoutSessionViewModelTests.swift
├── WorkoutSessionViewModelTests.swift     └── Match/
└── Match/                                     ├── CrownPointGateTests.swift
    └── ScoreViewModelTests.swift              ├── ScoreViewModelHapticsTests.swift
                                               └── ScoreViewModelTests.swift
```

`Mode/`·`Score/`·`Result/` 안의 파일과 각자의 `Components/` 는 그대로 따라간다 (Swift 28개 + 테스트 4개).

## Task 4: 소스·테스트 폴더 이동

**Files:**
- Move: `iOSApp/Features/Match/` → `iOSApp/Features/WorkoutSession/Match/`
- Move: `WatchApp/Features/Match/` → `WatchApp/Features/WorkoutSession/Match/`
- Move: `iosTests/Match/` → `iosTests/WorkoutSession/Match/`
- Move: `watchosTests/Match/` → `watchosTests/WorkoutSession/Match/`

- [ ] **Step 1:** 브랜치 생성, 이 플랜 갱신분과 루트 `TODO.md` 행을 첫 커밋으로

```bash
git switch -c refactor/ralli-match-folder-move origin/main   # main 은 다른 워크트리가 잡고 있어 origin/main 에서 바로 분기
git branch -d refactor/ralli-match-view-deps                  # 머지된 1단계 로컬 브랜치 정리
git add Apps/TennisCounter/docs/plans/shared/2026/2026-10-06-match-view-dependency-cut.md TODO.md
git commit -m "📝 매치 폴더 재배치(A안)를 플랜 2단계로 이어 쓴다"
```

- [ ] **Step 2:** 이동

```bash
cd Apps/TennisCounter
git mv iOSApp/Features/Match        iOSApp/Features/WorkoutSession/Match
git mv WatchApp/Features/Match      WatchApp/Features/WorkoutSession/Match
git mv iosTests/Match               iosTests/WorkoutSession/Match
git mv watchosTests/Match           watchosTests/WorkoutSession/Match
```

- [ ] **Step 3:** 확인
  - `git diff --stat HEAD -- '*.pbxproj'` → 출력 없음
  - `find . -path '*/Features/Match' -o -path '*Tests/Match'` → 출력 없음
  - `git status` 가 rename 32건만 보이는지 (내용 변경 없음)
- [ ] **Step 4:** 빌드 — `TennisCounter`, `TennisCounter Watch App` 두 스킴
- [ ] **Step 5:** 커밋 `♻️ Match 폴더를 WorkoutSession 하위로 옮긴다`

## Task 5: 문서 갱신

**Files:**
- Modify: `Apps/TennisCounter/CLAUDE.md`
- Modify: `Apps/TennisCounter/iOSApp/Features/WorkoutSession/README.md`
- Modify: `Apps/TennisCounter/WatchApp/Features/WorkoutSession/README.md`
- Modify: `CLAUDE.md` (루트)

- [ ] **Step 1:** 앱 `CLAUDE.md`
  - Architecture 트리 — iOS·Watch 모두 `Match/` 를 `WorkoutSession/` 아래로. Watch `Match/` 주석 "경기 도메인 (Workout과 독립적)" 은 "WorkoutSession 하위 흐름 — 모드 선택 → 점수 입력 → 결과" 로
  - WorkoutSession 주석의 "Match 흐름 조정" 등은 유지
  - **ScoreViewModel** 항목의 위치 — `WorkoutSession/Match/Score/ScoreViewModel.swift`
  - Testing 미러링 트리 — `iosTests/`·`watchosTests/` 의 `Match/` 를 `WorkoutSession/Match/` 로, 대응 경로 주석도
- [ ] **Step 2:** 두 `WorkoutSession/README.md` 의 `ScoreViewModel` 절 경로 표기 (iOS 263행, Watch 247행). 그 밖의 `Features/Match` 표기가 없는지 grep
- [ ] **Step 3:** 루트 `CLAUDE.md` "ViewModel 전달 (단방향)" 절 — Ralli 가 더는 "다른 Feature" 예가 아니다
  - 코드 예시 주석: "ViewModel 을 가진 쪽 — 다른 Feature 의 화면에는…" → "ViewModel 을 가진 쪽 — 자식 화면에는 값과 콜백만 넘긴다",
    "다른 Feature 의 화면 — ViewModel 이름을 모른다" → "자식 화면 — ViewModel 이름을 모른다"
  - 기준 구현의 Ralli 항목 → "같은 Feature 지만 쓰는 멤버가 적어 값과 콜백을 쓴 예: Ralli `WorkoutSession/` → `Match/` 화면 (iOS·워치)"
  - 규칙 문장·표는 바꾸지 않는다
- [ ] **Step 4:** 남은 옛 경로 확인

```bash
grep -rn 'Features/Match\|Tests/Match\|`Match/Score' CLAUDE.md Apps/TennisCounter/CLAUDE.md Apps/TennisCounter/*/Features/WorkoutSession/README.md
```

  Expected: 출력 없음

- [ ] **Step 5:** 커밋 `📝 Match 폴더 이동에 맞춰 구조 문서와 규칙 예시를 갱신한다`

## Task 6: 검증 · PR · 정리

```bash
make lint && make format
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" -only-testing:RalliTests test
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter Watch App" -destination "id=$WATCH" -only-testing:RalliWatchTests test
```

- [ ] **Step 1:** lint·format·테스트. 기대값은 1단계 재검증과 같다 — `RalliTests` 224개, `RalliWatchTests` 93개 (테스트는 경로만 바뀐다)
- [ ] **Step 2:** PR 생성. 본문에 "코드 변경 없음 — rename 32건 + 문서" 를 밝힌다
- [ ] **Step 3:** 수동 확인 — 동작 변경이 없어 앱 확인은 필요 없다. Xcode 에서 워크스페이스를 열어 네비게이터에 `WorkoutSession/Match/` 가 정상으로 보이는지만 본다
- [ ] **Step 4:** 머지(확인 후) `gh pr merge <n> --merge --delete-branch`, 루트 `TODO.md` 행 취소선 + 이 문서 상단 표 갱신
- [ ] **Step 5:** Notion 갱신 (확인 후)
  - 이 논의 페이지 — "결정해야 할 것" 을 결론(A·B 둘 다 진행, `MatchFlowView` 보류)과 PR 링크로 정리
  - 상위 "Ralli - Tennis Counter" 페이지 "구조" 섹션의 폴더 트리

## 2단계 실행 기록

(실행하며 채운다 — rename 건수, pbxproj diff 여부, 테스트 수)
