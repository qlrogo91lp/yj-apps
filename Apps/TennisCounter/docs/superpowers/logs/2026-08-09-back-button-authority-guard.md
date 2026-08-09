# 뒤로가기 버튼 권한 가드 버그 수정

## 작업일: 2026-08-09

## 증상

실기기 테스트 중 발견. 폰이 워크아웃 컨트롤 화면(워크아웃 탭)에 있는 상태에서 뒤로가기를 눌렀더니 폰만 매치가 모드선택으로 초기화되고, 워치는 계속 경기 중이었다. 두 기기가 같은 매치를 진행 중이라는 전제 자체가 깨진 것 — 폰은 매치가 끝났다고 생각하고 워치는 계속 점수를 세는 상태로 갈라졌다.

---

## 근본 원인 2가지

두 결함이 겹쳐야 이 증상이 나온다. 하나만 있었다면 드러나지 않았을 것이다.

### 결함 1 — iOS 툴바가 `TabView`에 걸려 두 탭이 공유한다

`iOSApp/Features/WorkoutSession/WorkoutSessionView.swift`의 `.toolbar`가 개별 탭이 아니라 `TabView` 자체에 붙어 있었다. `WorkoutSessionView`는 워크아웃 탭(tag 0)·매치 탭(tag 1)의 2탭 컨테이너인데, leading 툴바 아이템의 분기는 `selectedTab`을 보지 않고 `viewModel.phase`만 봤다:

```swift
TabView(selection: $selectedTab) {
    WorkoutDashboardView(...).tag(0)
    scoreTabContent.tag(1)
}
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        switch viewModel.phase {          // ← selectedTab을 보지 않는다
        case .playing:
            BackButton { ... startNewMatch() ... }
        ...
```

결과: **워크아웃 컨트롤 화면(탭 0)의 뒤로가기 = 매치 리셋 버튼**이었다. `hasMatchProgress`가 false면(예: 0-0) 확인 알림도 없이 즉시 리셋됐다. 이건 mirror뿐 아니라 **driver에서도 재현되는 문제**였다 — 워크아웃 탭에 있다는 이유만으로 매치를 실수로 끝낼 수 있었다.

바로 아래 `.principal` 아이템(`WorkoutIndicator` 표시)은 `selectedTab == 1`을 이미 체크하고 있었다. 즉 "탭 인지가 필요하다"는 걸 같은 파일 안에서 알고 있었는데, leading 슬롯에만 그 처리가 누락된 상태였다.

### 결함 2 — `startNewMatch`가 권한과 무관하게 로컬 상태를 리셋한다

`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`(워치는 `WatchApp/.../WorkoutSessionViewModel.swift`, 동일 구조):

```swift
func startNewMatch(notifyRemote: Bool = true) {
    if notifyRemote, isDriver, case .playing = phase {
        connectivity.sendMatchReset(sessionId: sessionId)   // ← isDriver일 때만 상대에게 알림
    }
    _currentSession = nil
    phase = .modeSelection                                   // ← 권한과 무관하게 무조건 로컬 리셋
}
```

`sendMatchReset` 호출은 `isDriver` 가드 안에 있어 mirror에서는 나가지 않는데, 그 아래 `phase = .modeSelection`은 가드 밖에 있어 무조건 실행됐다. 그래서 mirror가 이 함수를 호출하면 상대에게 알리지도 않고 자기 화면만 조용히 리셋한다 — driver는 계속 경기 중, mirror만 모드선택으로 이탈.

여기에 한 가지 더: mirror는 `applyRemoteState`가 `snapshots.removeAll()`을 하기 때문에 `canUndo`가 항상 false이고, `hasMatchProgress`는 `canUndo`를 포함하는 조건이라 **첫 게임이 끝나기 전(예: 30-15)에는 확인 알림조차 없이** 즉시 리셋되는 최악의 경로였다.

결함 1과 2는 독립적으로도 문제지만, 겹치면 "워크아웃 탭에서 뒤로가기 → mirror 조용히 리셋"이라는 정확히 이 증상이 만들어진다.

---

## 왜 워치는 안 그랬나

워치(`WatchApp/Features/WorkoutSession/WorkoutSessionView.swift`)는 애초에 결함 1이 없었다. 3탭(`WorkoutControlsView` / Match / `WorkoutMetricsView`) 구조에서 각 탭이 **자기 툴바를 개별 선언**하고, 워크아웃 쪽 탭들은 leading 슬롯을 `Color.clear.frame(width: 36, height: 36)` 투명 플레이스홀더로 이미 덮어놓고 있었다. iOS `WorkoutSessionView`에는 이 처리가 빠져 있었던 것 — 같은 문제를 워치는 이미 한 번 풀어놓고 iOS 쪽에 이식을 안 한 상태였다.

다만 워치도 결함 2(`startNewMatch`의 권한 없는 로컬 리셋)와 매치 화면(`ScoreView`) 자체의 mirror 뒤로가기 노출은 iOS와 동일하게 갖고 있었다 — Task 2·4가 이걸 다룬다.

---

## 수정 범위 결정

### 가드를 `.playing`으로만 한정한 이유

`.finished`(결과 화면)까지 막으면 mirror가 결과 화면에 갇힌다. driver가 결과 화면에서 뒤로가기를 누를 때는 `sendMatchReset`을 보내지 않으므로(이미 끝난 매치라 동기화할 게 없음) mirror에게 알려줄 방법도 없다 — 즉 `.finished`는 애초에 두 기기가 어긋날 진행 상태가 없는 단계라, 여기서는 mirror도 자기 판단으로 화면을 닫을 수 있어야 한다. 그래서 가드 조건은 `case .playing = phase`로만 좁혔다.

### `restartMatch()`를 건드리지 않은 이유

mirror의 rematch 동작은 기존 테스트 `restartMatchPreservesMirrorRole`이 이미 보장하는 의도된 동작이라 별개 사안으로 분리했다.

### `isDriver`를 `@Published`로 바꾸지 않은 이유

`isDriver`는 `startMatch()` 안에서 `phase`와 항상 함께 바뀌고, `phase`가 `@Published`이므로 View는 이미 간접적으로 갱신된다. 기존 `ScoreView(isDriver:)` 전달도 이 동작에 의존하고 있어, 이번 플랜에서 `@Published`로 전환하면 버그 수정과 무관한 변경이 섞이게 된다. 그대로 뒀다.

---

## Before/After 코드

### `startNewMatch` — iOS (`iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`)

```swift
// Before
func startNewMatch(notifyRemote: Bool = true) {
    if notifyRemote, isDriver, case .playing = phase {
        connectivity.sendMatchReset(sessionId: sessionId)
    }
    _currentSession = nil
    phase = .modeSelection
}

// After
func startNewMatch(notifyRemote: Bool = true) {
    if notifyRemote, case .playing = phase {
        // 진행 중인 매치를 끝낼 권한은 driver에게만 있다. mirror가 로컬로 리셋하면
        // sendMatchReset이 나가지 않아 driver는 계속 경기 중인데 mirror만 모드선택으로 빠진다.
        // 수신 경로(notifyRemote: false)는 이 가드를 타지 않는다 — mirror가 driver의 리셋을 받는 유일한 통로다.
        guard isDriver else { return }
        connectivity.sendMatchReset(sessionId: sessionId)
    }
    _currentSession = nil
    phase = .modeSelection
}
```

`isDriver` 체크를 `if` 조건에서 `guard`로 옮긴 게 핵심이다. 이전에는 `isDriver`가 `sendMatchReset` 호출 여부만 결정하고 `phase = .modeSelection`은 무조건 실행됐다. 이제는 `.playing` + `notifyRemote: true`인데 mirror면 함수 전체가 `return`으로 빠져 아무 상태도 바뀌지 않는다. (커밋 `98ad1d0`)

### `startNewMatch` — Watch (`WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift`)

```swift
// Before
func startNewMatch(notifyRemote: Bool = true) {
    if notifyRemote, isDriver, case .playing = phase {
        connectivity.sendMatchReset(sessionId: activeSessionId)
    }
    _currentSession = nil
    phase = .modeSelection
    saveAckState = .idle
    saveAttemptToken += 1
}

// After
func startNewMatch(notifyRemote: Bool = true) {
    if notifyRemote, case .playing = phase {
        // 진행 중인 매치를 끝낼 권한은 driver에게만 있다. mirror가 로컬로 리셋하면
        // sendMatchReset이 나가지 않아 driver는 계속 경기 중인데 mirror만 모드선택으로 빠진다.
        // 수신 경로(notifyRemote: false)는 이 가드를 타지 않는다 — mirror가 driver의 리셋을 받는 유일한 통로다.
        guard isDriver else { return }
        connectivity.sendMatchReset(sessionId: activeSessionId)
    }
    _currentSession = nil
    phase = .modeSelection
    saveAckState = .idle
    saveAttemptToken += 1
}
```

iOS와 대칭 구조. 워치 전용 `saveAckState`/`saveAttemptToken` 리셋은 가드 이후 로직이라 mirror가 no-op으로 반환할 때는 이 값들도 건드려지지 않는다 — 애초에 바뀐 게 없으니 되돌릴 ack 상태도 없다는 게 의도된 동작. (커밋 `894840d`)

### iOS 툴바 — `WorkoutSessionView.swift`

```swift
// Before
ToolbarItem(placement: .topBarLeading) {
    switch viewModel.phase {
    case .modeSelection:
        BackButton { selectedTab = 0 }
    case .playing:
        BackButton {
            if hasMatchProgress {
                showEndMatchConfirm = true
            } else {
                viewModel.startNewMatch()
            }
        }
    case .finished:
        BackButton { viewModel.startNewMatch() }
    }
}

// After
ToolbarItem(placement: .topBarLeading) {
    if selectedTab == 1 {
        matchBackButton
    } else {
        // 툴바가 개별 탭이 아니라 TabView에 걸려 두 탭이 공유한다. 워크아웃 탭에
        // 매치용 뒤로가기가 새어나가지 않도록 자리만 비운다 (워치와 같은 방식 —
        // 슬롯을 없애면 .principal 아이템 위치가 흔들린다).
        Color.clear.frame(width: 36, height: 36)
    }
}
```

원래 있던 phase 분기는 새 computed property `matchBackButton`으로 옮기면서 `.playing` 케이스에 mirror 숨김을 추가했다:

```swift
@ViewBuilder
private var matchBackButton: some View {
    switch viewModel.phase {
    case .modeSelection:
        BackButton { selectedTab = 0 }
    case .playing:
        if viewModel.isDriver {
            BackButton {
                if hasMatchProgress {
                    showEndMatchConfirm = true
                } else {
                    viewModel.startNewMatch()
                }
            }
        } else {
            Color.clear.frame(width: 36, height: 36)
        }
    case .finished:
        BackButton { viewModel.startNewMatch() }
    }
}
```

`selectedTab == 1` 게이팅으로 결함 1을, `.playing` 안의 `isDriver` 분기로 결함 2에 대응하는 View 쪽 노출을 막았다. (커밋 `3a99837`)

### Watch 툴바 — `ScoreView.swift`

```swift
// Before
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        BackButton {
            if viewModel.mySetScore == 0, viewModel.yourSetScore == 0,
               viewModel.myGameScore == 0, viewModel.yourGameScore == 0
            {
                flowViewModel.startNewMatch()
            } else {
                showExitConfirm = true
            }
        }
    }
}

// After
.toolbar {
    ToolbarItem(placement: .topBarLeading) {
        // 진행 중인 매치를 끝낼 권한은 driver에게만 있다 (점수 입력·undo와 같은 규칙).
        // mirror에게는 눌러도 아무 일 없는 버튼 대신 자리를 비운다 — 워크아웃 탭들과 같은 방식.
        if flowViewModel.isDriver {
            BackButton {
                if viewModel.mySetScore == 0, viewModel.yourSetScore == 0,
                   viewModel.myGameScore == 0, viewModel.yourGameScore == 0
                {
                    flowViewModel.startNewMatch()
                } else {
                    showExitConfirm = true
                }
            }
        } else {
            Color.clear.frame(width: 36, height: 36)
        }
    }
}
```

워치는 결함 1(탭 간 툴바 누수)이 원래 없었으므로 mirror 숨김만 추가하면 됐다. (커밋 `54819c8`)

---

## 테스트

Task 1(iOS)·2(Watch)에서 총 7개 추가. 워크아웃 세션 ViewModel은 이미 iOS/Watch 각각 `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`, `watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`에 있고, 이번 테스트는 그 파일 끝에 추가됐다.

**iOS (`iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`, 커밋 `98ad1d0`)**

| 테스트 | 막는 회귀 |
|---|---|
| `mirrorCannotResetPlayingMatchLocally` | mirror가 `.playing` 상태에서 `startNewMatch()`를 호출해도 `phase`가 그대로 `.playing`으로 남아야 한다 — 이 리포의 **버그 재현 테스트**. 수정 전에는 `.modeSelection`으로 빠져 FAIL이었다. |
| `driverCanResetPlayingMatchLocally` | 위 가드가 driver의 정상 리셋까지 막지 않는지 확인. driver는 `.playing`에서 `startNewMatch()` 호출 시 `.modeSelection`으로 전환돼야 한다. |
| `mirrorCanLeaveFinishedResultScreen` | 가드를 `.playing`으로 한정한 결정을 고정한다. mirror도 `.finished`에서는 `startNewMatch()`로 `.modeSelection`에 갈 수 있어야 한다 — 여기까지 막았다면 mirror가 결과 화면에 갇히는 회귀가 생긴다. |

**Watch (`watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift`, 커밋 `894840d`)**

| 테스트 | 막는 회귀 |
|---|---|
| `mirrorCannotResetPlayingMatchLocally` | iOS와 동일한 버그 재현 테스트. mirror가 `.playing`에서 로컬 리셋을 시도해도 무시되어야 한다. |
| `driverCanResetPlayingMatchLocally` | driver의 정상 리셋 경로 보존 확인. |
| `mirrorAppliesIncomingMatchReset` | 수신 경로(`startNewMatch(notifyRemote: false)`, `handleIncomingMatchReset`이 타는 경로)는 이 가드에 걸리지 않고 mirror도 `.modeSelection`으로 전환되는지 확인 — mirror가 driver의 리셋을 실제로 받아들이는 유일한 통로이므로, 가드를 잘못 걸면 이 경로 자체가 막혀버릴 위험이 있었다. |
| `mirrorCanLeaveFinishedResultScreen` | iOS와 동일하게 `.playing` 한정 결정을 고정. |

`mirrorCannotResetPlayingMatchLocally`(iOS·Watch 둘 다)는 RED→GREEN을 실측으로 확인했다. Task 1 리포트에서 수정 전 실행 결과가 `Issue.record("mirror의 로컬 리셋은 무시되고 playing이 유지되어야 함")`로 FAIL이었고, 가드 구현 후 재실행에서 `** TEST SUCCEEDED **`로 전환된 걸 확인했다 — 이 테스트가 버그를 실제로 재현하고 수정을 검증했다는 뜻이다. 기존 회귀 테스트(`mirrorMatchResetReturnsToModeSelection`, `remoteStartMatchSyncsSessionIdForMatchReset`, `startNewMatchResetsSaveAckState` 등)도 모두 계속 통과했다 — 수신 경로와 driver 경로가 이번 변경으로 깨지지 않았다는 뜻이다.

Task 3(iOS 툴바)·Task 4(Watch 툴바)는 View 변경이라 CLAUDE.md 규약대로 단위 테스트를 추가하지 않았다. 검증 방식은 아래 "남은 것" 참고.

---

## 남은 것

View 변경분(Task 3·4)은 애초에 단위 테스트 대상이 아니다. 계획대로라면 시뮬레이터에서 탭 기반 수동 확인 후, 최종적으로 실기기 2대 회귀로 마무리하는 흐름이었는데, **이 개발 환경에서 iOS Simulator MCP 도구(`mcp__Claude_Code_iOS_Simulator__control`)가 고장나 있어** 계획대로 진행하지 못했다.

증상: `attach` 호출이 "Xcode is installed but not selected. Run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`..."로 실패한다. 그런데 같은 셸에서 `xcode-select -p`는 정확한 경로(`/Applications/Xcode.app/Contents/Developer`)를 반환하고 `xcodebuild -version`·`xcrun simctl`도 정상 동작한다 — 도구 자체의 내부 점검 로직이 실제 Xcode 설정과 무관하게 잘못된 진단을 내리는 것으로 보인다. 제안된 해결책이 `sudo`를 요구하는데 이건 비대화형 환경에서 비밀번호를 넣을 수 없어 실행하지 않았다. AppleScript/System Events로 우회 시도도 했으나 `osascript에 보조 접근이 허용되지 않습니다. (-1719)` — 접근성 권한이 없어서 막혔다. `idb`/`cliclick` 등 대체 도구도 설치돼 있지 않았다.

그래서 Task 3·4는 다음으로 대체했다:
1. `xcodebuild ... build` 성공 확인 (실제 컴파일 통과).
2. `xcrun simctl install`/`launch`/`io screenshot`로 앱이 시뮬레이터에서 크래시 없이 뜨는지 확인 (Task 3에서 홈 탭 스크린샷 1장 확보).
3. 브리프의 확인 테이블 각 행을 diff와 소스 코드 대조로 하나씩 짚어 "코드가 기대 동작과 일치하는지"를 검증 (탭 기반 실측이 아닌 정적 트레이스).

Task 3 리뷰에서 이 사실이 "minor (deferred)"로 기록되어 있다 (진행 로그 `progress.md` 참고) — 리뷰어가 이 대체 검증 방식(소스 코드·diff 트레이스)을 승인했지만, **실기기 2대 회귀 단계에서 실제 탭 확인이 아직 필요**하다는 점은 명시적으로 남겨뒀다. (Task 1도 "minor (deferred)"로 기록되어 있으나 이는 별개 사항 — 리포트 서술의 정확성 관련). Task 4도 같은 시뮬레이터 도구 제약을 받았지만 리뷰어가 소스 트레이스 검증으로 승인했기에 별도 ledger 항목이 없다. 특히 mirror가 실제로 뒤로가기 버튼을 숨기는 행(워치가 driver, 폰이 mirror인 조합)은 페어링된 두 번째 기기 없이는 애초에 시뮬레이터로도 확인 불가능한 항목이라, 이 플랜의 최종 검증은 처음부터 실기기 2대 회귀로 예정돼 있었다.

최종 확인은 아래 체크리스트로 남겨둔다.

- [ ] iOS 테스트 `** TEST SUCCEEDED **`
- [ ] Watch 테스트 `** TEST SUCCEEDED **`
- [ ] iOS·Watch Release 빌드 통과
- [ ] 워치에서 매치 시작(워치 driver) → 폰이 자동 합류(mirror) → 폰 점수 화면에 뒤로가기 없음
- [ ] 같은 상태에서 폰 워크아웃 탭 → 뒤로가기 없음 (원 증상 재현 경로)
- [ ] 워치에서 점수 진행 → 폰에 계속 반영됨 (가드가 미러링을 막지 않았는지)
- [ ] 워치(driver)에서 뒤로가기 → 확인 후 종료 → 폰도 함께 모드선택으로 복귀 (matchReset 수신 경로 정상)
- [ ] 폰에서 매치 시작(폰 driver) → 워치가 mirror → 워치 점수 화면에 뒤로가기 없음
- [ ] 폰(driver)에서 뒤로가기 → 워치도 함께 모드선택으로 복귀
- [ ] 매치 종료 후 결과 화면 → mirror 쪽에서도 뒤로가기 동작함 (`.finished`는 의도적으로 허용)
- [ ] 매치 진행 중 폰 탭 전환 시 상단 경과시간 위치가 흔들리지 않음

---

## 변경 파일 요약

| 파일 | 변경 내용 |
|---|---|
| `iOSApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `startNewMatch`에 mirror 권한 가드 (`98ad1d0`) |
| `WatchApp/Features/WorkoutSession/WorkoutSessionViewModel.swift` | `startNewMatch`에 mirror 권한 가드 (대칭, `894840d`) |
| `iOSApp/Features/WorkoutSession/WorkoutSessionView.swift` | 툴바 leading 아이템 탭 게이팅(`selectedTab == 1`) + `matchBackButton`으로 mirror 숨김 분리 (`3a99837`) |
| `WatchApp/Features/Match/Score/ScoreView.swift` | 툴바 leading 아이템 `isDriver` 게이팅으로 mirror 숨김 (`54819c8`) |
| `iosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` | 권한 가드 테스트 3개 추가 |
| `watchosTests/WorkoutSession/WorkoutSessionViewModelTests.swift` | 권한 가드 테스트 4개 추가 |
