# 워치 운동 종료 중복 요청 방지 — 구현 플랜

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:executing-plans`로 현재 세션에서 순서대로 진행한다. 구현은 이 플랜의 사용자 승인 후 시작한다.

**Goal:** 운동 종료를 연속으로 눌러도 HealthKit 마무리를 한 번만 수행하고, 시작 화면이 끼어들지 않은 채 결과 화면으로 이동한다.

**Architecture:** `WorkoutViewModel`이 `isEnding`으로 종료 작업의 재진입을 막는다. `SessionView`는 이 상태를 받아 종료 중 표시와 조작 잠금을 제공한다. HealthKit 종료 호출만 비동기 클로저로 주입 가능하게 해, 실제 세션 없이 완료 시점을 통제하는 회귀 테스트를 작성한다.

**Tech Stack:** Swift · SwiftUI · Combine · Swift Testing · watchOS 10 이상.

**Spec:** 이 문서의 「확인한 원인과 동작 계약」이 이번 버그 수정의 범위다. 기존 저장·버리기 동작은 [W2 플랜](2026-09-07-haruchi-fit-w2-summary.md), 정지 제외 시간 계산은 [시간 스펙](../../../specs/watch/2026/2026-09-09-workout-elapsed-exclude-pause.md)을 따른다.

**Status:** 사용자 승인 후 구현·자동 검증 완료. 워치 전체 199개 테스트·lint·format 통과. 독립 코드 리뷰 Critical/Important 없음. 실기기/UI 확인 대기.

## 확인한 원인과 동작 계약

- `SessionView`의 종료 콜백은 호출마다 새 `Task`를 만들고, 종료 버튼은 마무리 대기 중에도 활성 상태다.
- `WorkoutViewModel.end()`에는 중복 요청 방어가 없다.
- `WorkoutSessionService.stopWorkout()`은 첫 비동기 대기 전에 세션 참조를 비운다. 그 사이 두 번째 호출은 `nil`을 반환한다.
- 두 번째 호출의 `enterSummary(with: nil)`이 `.idle`로 보내고, 첫 번째 호출이 완료되면 `.summary`가 된다.
- 실제 `end()`와 `enterSummary()`를 추출하고 HealthKit 서비스를 지연 가능한 대역으로 바꾼 Swift 하네스에서 위 순서를 확인했다. 실기기에서 관찰한 현상의 실제 입력 횟수는 아직 확인하지 않았다.

동작 계약:

1. 첫 종료 요청은 **첫 await와 구간 닫기 전에** `isEnding = true`를 설정한다.
2. 종료 중 추가 `end()`는 `nil`을 반환하며, 구간·스냅샷·단계·보관 기록을 변경하지 않는다. 이미 결과 화면일 때 도착한 `end()`도 무시한다.
3. 종료 중에는 운동 화면 위에 불투명한 진행 표시를 띄운다. 문구는 `workout_ending`: 한국어 **운동 종료 중…**, 영어 **Ending workout…**. 진행 표시에는 퍼센트나 취소 버튼을 넣지 않는다.
4. 종료 중 시작·시작 유형 선택·진행 유형 전환·정지/재개를 UI와 뷰모델 양쪽에서 막는다. 종료 도중 들어오는 pause 상태는 기존처럼 시계에 반영하되 컴플리케이션 스냅샷을 새로 발행하지 않는다.
5. 최초 요청이 결과를 받으면 보관 기록을 만들고 `.summary`로 전환한다. `defer`로 `isEnding`을 해제한다. 실제 결과가 없으면 기존처럼 `.idle`로 복귀하며 잠금도 풀린다.
6. 구간 종료와 `totalSeconds` 캡처는 최초 종료 요청에서 한 번만 수행한다. HealthKit 완료를 기다린 시간이 저장 운동 시간에 더해지면 안 된다.

## Global Constraints

- HaruchiFit 워치 앱 내부 수정이다. YJKit의 `stopActivity → endCollection → finishWorkout → end` 순서를 유지한다.
- `SessionPhase`와 `WorkoutRootView`는 그대로 사용한다. `isEnding`은 `.active`와 병존하는 일시적인 작업 상태다.
- iOS·다른 앱·전송 페이로드·저장/버리기 정책은 변경하지 않는다. HealthKit의 기존 오류 처리·타임아웃 확장은 별도 작업이다.
- 화면 문자열은 워치 String Catalog의 의미 키로 ko/en을 함께 작성한다.
- 테스트는 Swift Testing으로 ViewModel 동작을 검증한다. View 테스트는 추가하지 않는다.
- 사용자 작업 중인 변경을 보존한다. 특히 `TODO.md` 전체를 되돌리거나 통째로 스테이징하지 않는다.
- 브랜치·커밋은 아래 제안 범위에 포함한다. 구현 결과는 사용자 검토 후 커밋하며 PR 생성·push·merge는 별도 요청 시 진행한다.

## 변경 파일

아래 앱 상대 경로의 기준은 `Apps/HaruchiFit/`이다.

| 파일 | 변경 |
|---|---|
| `WatchApp/Features/Workout/WorkoutViewModel.swift` | `isEnding`, 재진입 방어, 종료 중 조작 방어, 종료 클로저 주입 |
| `WatchApp/Features/Workout/Session/SessionView.swift` | 종료 중 전체 조작 비활성화, 접근성 처리, 진행 표시 오버레이 |
| `WatchApp/Localizable.xcstrings` | `workout_ending` ko/en 추가 |
| `watchosTests/Workout/WorkoutViewModelEndingTests.swift` | 생성: 중복 요청·지연·완료·nil 결과·조작 잠금 검증 |
| `watchosTests/Support/WorkoutStopperSpy.swift` | 생성: 호출 횟수와 비동기 완료 시점을 통제하는 대역 |
| `docs/logs/2026/2026-11-04-workout-end-reentrancy.md` | 구현 시 생성: 원인·수정·검증 결과와 실기기 미확인 항목 기록 |
| 루트 `TODO.md` | 이 플랜 링크·승인 대기 상태 추가, 구현 시 검증 상태 갱신 |

## Review Focus

- 종료를 연속으로 눌렀을 때 서비스 호출·구간 닫기·스냅샷 삭제가 한 번인지 — Task 1 회귀 테스트.
- 첫 요청 완료 전 단계가 바뀌거나 기록이 만들어지는지 — Task 1 단계 발행 이력 검사.
- 완료 지연 중 시계를 진행시켜도 총 시간·구간이 늘어나지 않는지 — Task 1 고정 시계 테스트.
- 결과 화면 진입 후 늦게 도착한 종료 요청이 기록을 지우는지 — Task 1 결과 이후 재호출 테스트.
- nil 결과 및 정지 상태에서 종료 후 잠금이 남는지 — Task 1 nil 테스트, Task 2 실기기 정지 종료 확인.

## Task 0: 승인된 작업 공간 준비

- [x] 플랜 승인 후 `fix/haruchi-workout-end-reentrancy` 브랜치와 형제 경로 `../yj-apps-worktrees/haruchi-workout-end-reentrancy`에 격리된 워크트리를 준비한다. 루트 워크트리 규약과 `using-git-worktrees` 스킬을 따른다.
- [x] 승인된 플랜과 이번 TODO 추가분을 작업 공간에 반영하되, 기존 미커밋 작업을 옮기거나 커밋하지 않는다.

## Task 1: 종료 작업을 한 번만 수행한다

**Files:** `WorkoutViewModel.swift`, 신규 `WorkoutViewModelEndingTests.swift`, 신규 `WorkoutStopperSpy.swift`.

**Interfaces:**

- 공개 상태: `@Published private(set) var isEnding = false`.
- 기존 initializer 마지막에 `stopWorkout: (@MainActor () async -> WorkoutResult?)? = nil` 추가. 내부 저장 클로저의 기본값은 전달받은 `session.stopWorkout()`을 호출한다. 기존 호출부의 변경은 필요 없다.
- 테스트 대역: `@MainActor final class WorkoutStopperSpy`, `private(set) var callCount: Int`, `func stop() async -> WorkoutResult?`, `func complete(with result: WorkoutResult?)`. continuation으로 첫 호출을 멈추고 명시적으로 재개한다. 테스트는 대역 진입 신호를 기다리며 고정 sleep을 사용하지 않는다.
- 기존 `end() async -> WorkoutResult?` 시그니처는 유지한다. 맨 앞에서 `!isEnding && phase != .summary`를 검사한다. 기존의 세션 없는 종료 경로와 스냅샷 테스트를 유지하기 위해 `.active`만 허용하는 별도 변경은 하지 않는다.

- [x] 클로저 주입 지점과 테스트 대역을 추가한 뒤 아래 테스트를 작성한다. 실제 HealthKit 시작을 호출하지 않고 테스트의 시계·지연 대역으로 종료 로직을 실행한다.
  - `duplicateEndDoesNotInterruptPendingEnd`: 첫 종료를 중단해 둔 뒤 추가 종료를 호출한다. `callCount == 1`, `isEnding == true`, `pendingRecord == nil`, 초기 발행을 제외한 단계 변경이 없음, 스냅샷 `clearCount == 0`. 완료 후 `.summary`, `isEnding == false`, `clearCount == 1`, 결과 UUID 일치를 검사한다.
  - `endingCapturesDurationAndSegmentsOnce`: 주입 시계를 60초 진행 후 종료, 대기 중 30초 추가 진행 및 중복 종료. 완료 기록의 `totalSeconds == 60`, 구간 개수 `1`, 구간 길이 합 `60`.
  - `lateEndPreservesSummary`: 결과 보관 후 다시 종료해도 서비스 호출 횟수·UUID·단계·스냅샷 삭제 횟수가 변하지 않는다.
  - `nilResultClearsEnding`: 대역이 nil로 완료되면 `.idle`, `pendingRecord == nil`, `isEnding == false`이고 다음 종료 요청은 다시 대역에 도달할 수 있다.
  - `actionsAreIgnoredWhileEnding`: 종료 대기 중 `start`, `toggleStartKind`, `switchMode`, `togglePause`가 상태·유형·설정값·스냅샷을 변경하지 않는다. `start`는 권한 요청에 도달하지 않고 반환해야 한다.
  - `pauseChangeDoesNotPublishWhileEnding`: 대기 중 `handlePauseChange`를 호출해도 스냅샷 발행 횟수가 늘지 않는다.
- [x] 회귀 테스트를 실행해 현재 동작에서 실패함을 확인한다. 빌드 실패와 동작 assertion 실패를 구분한다.
- [x] `end()`의 검사·잠금·`defer` 해제와 클로저 호출을 구현한다. 검사와 잠금은 첫 await 앞의 같은 MainActor 구간에서 처리한다.
- [x] `start`, `toggleStartKind`, `switchMode`, `togglePause`에 종료 중 조작 방어를 넣고, `handlePauseChange`의 스냅샷 발행 조건에 `!isEnding`을 추가한다.
- [x] 신규 회귀 테스트와 기존 WorkoutViewModel·pause·snapshot 테스트가 통과하는지 확인한다.

## Task 2: 종료 중임을 화면에 표시한다

**Files:** `SessionView.swift`, `WatchApp/Localizable.xcstrings`.

- [x] `SessionView`의 기존 `NavigationStack` 전체(툴바 포함)에 `.disabled(viewModel.isEnding)`을 적용한다.
- [x] `isEnding`이면 운동 화면 위를 시스템 배경으로 덮고 중앙에 `ProgressView`와 `workout_ending` 라벨을 표시한다. 오버레이는 비활성화되는 운동 화면 바깥에 조합한다. 뒤쪽 콘텐츠는 종료 중 접근성 탐색에서 숨긴다.
- [x] 카탈로그에 「운동 종료 중… / Ending workout…」를 추가한다.
- [ ] 작은 워치 화면·한국어/영어에서 문구와 스피너가 보이는지, 종료 대기 중 탭·크라운·툴바·VoiceOver로 운동을 조작할 수 없는지 확인한다.

## Task 3: 검증·기록·검토

- [x] 저장소 루트에서 워치 전체 테스트를 실행한다. 새 테스트뿐 아니라 기존 스냅샷 삭제·저장·버리기·정지 제외 시간 테스트도 통과해야 한다.

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFitWatchTests -destination "id=$WATCH" test
```

- [x] `Apps/HaruchiFit`에서 `swiftlint`, `swiftformat --lint .`를 실행한다. 기존 경고와 이번 변경의 오류를 구분하며 관련 없는 자동 수정은 하지 않는다.
- [ ] 실기기 확인: 한 번 종료, 빠른 연속 종료, 일시정지 후 종료, 종료 직후 손목 내림/복귀. 시작 화면 깜빡임 없이 결과가 한 번 표시되고 저장 후 폰·건강 앱에 기록이 하나씩 남는지 확인한다. 실기기를 사용할 수 없으면 이 항목을 미완으로 명시한다.
- [x] 작업 로그에 실제 검증 결과를 기록하고 TODO 상태를 갱신한다. 완료 항목은 취소선 처리하되 남은 실기기 확인을 별도로 유지한다.
- [x] diff를 검토해 요청 범위와 기존 작업 보존을 확인하고 사용자에게 결과를 제시한다.
- [x] 이번 파일과 TODO의 해당 변경만 커밋한다. 제안 메시지: `🐛 fix: 하루치 워치 운동 종료 중복 요청을 막는다`.
