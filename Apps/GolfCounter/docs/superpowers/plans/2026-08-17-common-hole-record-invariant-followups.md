# common: 홀 기록 불변식 후속 정리 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **이 문서는 실행 후 기록이다.** 4개 항목 모두 이 conversational 세션에서 inline TDD로 이미 구현·커밋·머지됐다. 사전 작성된 계획이 아니라, [PR #21](https://github.com/qlrogo91lp/golf_counter/pull/21)의 최종 리뷰가 남긴 항목을 어떻게 처리했는지 재구성한 것이다 — CLAUDE.md 워크플로우가 요구하는 "무엇을 바꿨는지 문서로 남긴다"를 사후에 채운다.

**Goal:** PR #21("홀 기록 불변식 — par-only 홀 제거")의 최종 whole-branch 리뷰가 스코프 밖으로 미룬 4개 항목을 plan ⑥(통계 탭) 착수 전에 정리한다.

**Architecture:** 네 항목은 서로 독립적이다 — 공통 아키텍처 결정은 없고, 각각 PR #21이 만든 특정 결함(테스트되지 않는 불변식 절반, 커버리지 갭, 문서 모호성 두 종류)을 좁게 겨냥한다.

**Tech Stack:** Swift 5(language mode) / SwiftData / SwiftUI / Swift Testing. 새 의존성 없음.

**선행 작업:** [PR #21](https://github.com/qlrogo91lp/golf_counter/pull/21) merged (merge commit `9dfc2b1`).

**후속 plan:** ⑥ `2026-08-13-ios-stats.md` (통계 탭) — 이 정리가 끝나야 착수한다.

## Global Constraints

- Deployment target: **iOS 17.0 / watchOS 10.0**
- 커밋 메시지는 gitmoji prefix, **main 직접 커밋 금지** — 브랜치 + PR
- 빌드 검증 시뮬레이터: iOS `iPhone 17 Pro`, watch/complication `Apple Watch Series 11 (46mm)`
- `make lint`(swiftlint) / `make format`(swiftformat --lint) 위반 0
- 새 파일 없음 — pbxproj 미변경
- 각 항목은 **동작 변경이 없거나(C·D), 있어도 순수 리팩터(A)** 다. B만 새 테스트가 실제로 뭔가를 검증하지만, 그 대상은 PR #21이 이미 올바르게 구현해 둔 동작이다 — 버그를 고치는 게 아니라 커버리지를 고정하는 것

## 실행 방식

**inline TDD, 세션 안에서 직접 실행** (subagent-driven-development 아님). PR #21은 SDD로 진행했지만, 이번 4항목은 각각 1~2파일짜리 기계적 작업이라 태스크별 서브에이전트+리뷰 오버헤드가 작업량을 넘는다고 판단해 사용자가 inline을 선택했다. 마지막에 `requesting-code-review`로 전체 diff를 한 번에 리뷰했다.

---

### Task A: `RoundEditViewModel.isSaveable` — 불변식을 테스트 가능한 타입으로

**Files:**
- Modify: `iOSApp/Features/History/Detail/RoundEditViewModel.swift`
- Modify: `iOSApp/Features/History/Detail/Components/HoleEditSheet.swift`
- Test: `iosTests/Features/History/Detail/RoundEditViewModelTests.swift`

**배경:** `HoleEditSheet`의 doc comment는 "불변식은 전부 `RoundEditViewModel`이 강제하므로 이 뷰는 상태를 그리기만 한다"고 주장했지만, 실제로는 저장 버튼의 `.disabled(!RoundEditViewModel.parOptions.contains(model.par))`가 `par == 0 && score > 0`("해석 불가" 상태, invariant spec §3)을 막는 유일한 장치였다 — 뷰 안에만 있어 테스트되지 않았고, 파일 자신의 doc comment와도 어긋났다.

**Interfaces:**
- Produces: `RoundEditViewModel.isSaveable: Bool` (`Self.parOptions.contains(par)`)

- [x] **Step 1: 실패하는 테스트 작성**

```swift
    @Test func 저장가능_파가선택지에없으면_불가능하다() {
        let model = RoundEditViewModel(par: 0, score: 0, putts: 0)

        #expect(model.isSaveable == false)
    }

    @Test func 저장가능_파가선택지중하나면_가능하다() {
        let model = RoundEditViewModel(par: 4, score: 0, putts: 0)

        #expect(model.isSaveable == true)
    }
```

- [x] **Step 2: 실패 확인** — `Value of type 'RoundEditViewModel' has no member 'isSaveable'`

- [x] **Step 3: `isSaveable` 구현**

```swift
    /// 저장 버튼 활성화 조건. `par == 0 && score > 0`("해석 불가" 상태, invariant spec §3)이
    /// 저장될 수 없다는 불변식의 나머지 절반을 여기로 옮겼다 — `HoleEditSheet`는
    /// 이 프로퍼티를 그리기만 하고, 위반 여부 자체는 여기서 테스트한다.
    var isSaveable: Bool {
        Self.parOptions.contains(par)
    }
```

`HoleEditSheet.swift`의 `.disabled(!RoundEditViewModel.parOptions.contains(model.par))`를 `.disabled(!model.isSaveable)`로 교체.

- [x] **Step 4: 테스트 통과 확인** — iOS 타깃 전부 PASS

- [x] **Step 5: 커밋** — `8fe04bd ✨ feat: RoundEditViewModel에 isSaveable 추가 — 불변식을 테스트 가능한 타입으로`

---

### Task B: 중간 par-only 홀 전송 + `publishSnapshot` 발행값 커버리지

**Files:**
- Test: `watchosTests/Round/RoundViewModelTransmissionTests.swift`

**배경:** PR #21 최종 리뷰가 지적한 Task 3의 커버리지 갭 3건. 기존 정규화 테스트는 전부 **말단** 케이스만 다뤄 `trimmed()`가 홀 자체를 지웠다 — 정규화된 홀이 배열 **중간**에 파 0으로 남아 전송되는 경로(`invariant spec §5.3`)가 한 번도 검증되지 않았다. `finishRound()`의 `publishSnapshot()` 호출도 테스트마다 스파이를 만들고 버려서 실제 발행 내용이 고정된 적이 없었다.

**Interfaces:**
- Consumes: 없음 (기존 `HoleProgress.clearUnplayedHoles()`·`RoundViewModel.finishRound()`를 그대로 검증)

- [x] **Step 1: 테스트 작성**

```swift
    @Test func 종료하면_중간의_파만고른홀은_파가0인채_배열에남아전송된다() {
        let publisher = RoundSnapshotPublisherSpy()
        let transmitter = RoundTransmitterSpy()
        let viewModel = makeViewModel(publisher: publisher, transmitter: transmitter)
        playHole(viewModel, par: 4, strokes: 5)
        viewModel.goToNextHole()
        viewModel.selectPar(3) // 홀 2에 파만 남기고
        viewModel.goToNextHole() // 홀 3으로 — 홀 2는 배열 중간에 par-only로 남는다
        playHole(viewModel, par: 5, strokes: 4)

        viewModel.finishRound()
        viewModel.applyMetrics(nil)
        viewModel.saveAndTransmit()

        #expect(transmitter.sent.first?.holePars == [4, 0, 5])
        #expect(transmitter.sent.first?.holeScores == [5, 0, 4])
        #expect(viewModel.recordedHoleCount == 2)
        #expect(publisher.published.last?.holePars == [4, 0, 5])
        #expect(publisher.published.last?.holeScores == [5, 0, 4])
    }
```

기존 `종료하면_이전버튼으로_두고온_파만고른홀도_정리된다()`에 `holeScores` 단언 한 줄 추가(형제 테스트와 비대칭 해소).

- [x] **Step 2: 실행 확인 — RED가 아니라 즉시 GREEN이었다**

이 테스트는 버그를 잡는 게 아니라 이미 올바른 동작을 고정하는 것이므로, 구현 변경 없이 바로 통과했다. (`전부_파만고른_라운드는_빈라운드로_처리된다()`도 PR #21 당시 같은 이유로 즉시 통과했던 선례가 있다.)

- [x] **Step 3: 커밋** — `05cdde1 ✅ test: 종료 시 정규화 — 중간 홀 전송 모양 + 발행 스냅샷 검증`

---

### Task C: spec §N 참조에 문서명 명시

**Files:** (1차 4파일 + 최종 리뷰 지적으로 확장된 blast-radius 9파일, 총 13파일)
- `Shared/Models/RoundSnapshot.swift`, `Shared/Persistence/GolfRound.swift`, `Shared/Models/ScoreAggregate.swift`
- `iOSApp/Features/History/Detail/Components/HoleRow.swift`, `iOSApp/Features/History/Detail/RoundEditViewModel.swift`
- `WatchApp/Features/Round/Scorecard/ScorecardView.swift`, `WatchApp/Features/Round/HoleProgress.swift`, `WatchApp/Features/Round/RoundViewModel.swift`
- `iosTests/Shared/GolfRoundTests.swift`, `watchosTests/Shared/RoundSnapshotTrimTests.swift`, `watchosTests/Shared/ScoreAggregateTests.swift`, `watchosTests/Round/HoleProgressTests.swift`, `watchosTests/Round/RoundViewModelTransmissionTests.swift`

**배경:** 코드베이스에 spec 문서가 4개 존재한다 — rebuild(`2026-07-31`) / history-stats(`2026-08-13`) / watch-round-transmission(`2026-08-14`) / hole-record-invariant(`2026-08-16`). 같은 파일 안에서도 `(spec §3)`이 서로 다른 문서를 가리키는 경우가 있었다(`RoundSnapshot.swift`의 두 `spec §3`이 세 줄 간격으로 각각 rebuild와 history를 가리킴).

**Interfaces:** 없음 — doc comment 텍스트만 변경, 동작 변경 없음.

- [x] **Step 1: 1차 4파일 매핑 및 교체**

각 참조를 실제 문서 섹션과 대조해 접두어를 붙였다: `rebuild spec §N` / `history spec §N` / `transmission spec §N` / `invariant spec §N`. 예:

```swift
// RoundSnapshot.swift:4  (rebuild spec §3 — RoundSnapshot 정의, "복구+컴플리케이션 겸용")
// RoundSnapshot.swift:32 (history spec §3 — 집계 대상 홀 정의)
// RoundSnapshot.swift:58 (invariant spec §7 — recordedHoleCount)
```

- [x] **Step 2: 빌드·테스트 확인, 커밋** — `11b1da4 📝 docs: spec § 참조에 문서명 명시 — 4개 문서가 섞여 있던 것 정리`

- [x] **Step 3: 최종 코드 리뷰가 "절반만 적용됨"을 지적**

`ScorecardView.swift:62`가 `HoleRow.swift:4`와 "같은 규칙"이라고 서로 참조하는데 한쪽만 접두어가 붙어, 오히려 "이 둘은 다른 문서를 말하나?"라는 새 혼란을 만들었다. `RoundEditViewModel.swift`(이 세션이 Task A에서 직접 건드린 파일)를 포함해 PR #21의 blast-radius 안에 있는 나머지 bare 참조 9곳도 지적됐다.

**범위 판단:** 코드베이스 전체에는 이 계열의 bare `spec §N`이 약 90곳 있다. 리뷰는 "PR #21의 blast radius"로 한정해 확장하라고 권고했다 — 그 밖의 참조(예: `HomeViewModel.swift`, `StrokeRing.swift`)는 원래도 모호하지 않았고, 무관한 파일까지 건드리는 건 CLAUDE.md의 "무관한 리팩터링 금지" 원칙에 어긋난다고 판단해 제외했다.

- [x] **Step 4: blast-radius 9곳 추가 교체, 재검증, 커밋** — `8182d7a 📝 docs: spec § 참조 문서명 명시 — PR #21 관련 파일까지 확장`

---

### Task D: `ScoringView` 진행 중 표시 스펙에 명시

**Files:**
- Modify: `docs/superpowers/specs/2026-08-16-hole-record-invariant-design.md` (§6)

**배경:** PR #21 최종 리뷰가 발견: `WatchApp/Features/Round/ScoringView.swift`는 라이브(정규화 전) `viewModel.snapshot`을 `ScorecardView`에 그대로 넘긴다. §6의 표시 방어(par-only 홀 게이트를 `par > 0`에서 `par > 0 && score > 0`로 좁힘)는 레거시 데이터만 겨냥했는데, 실제로는 **지금 플레이 중인 홀**의 파도 가린다 — §3이 정상으로 정의한 진행 중 par-only 상태가 표시 층에서는 레거시 par-only 상태와 구분되지 않는다.

**Interfaces:** 없음 — 문서만, 코드 변경 없음.

- [x] **Step 1: §6에 단락 추가**

```markdown
**부수 효과 하나, 의도적으로 받아들인다.** `WatchApp/Features/Round/ScoringView.swift`는
`viewModel.snapshot`(정규화 전, 진행 중인 라이브 스냅샷)을 그대로 `ScorecardView`에
넘긴다. 그래서 방금 파를 고르고 아직 타수를 치지 않은 **현재 홀**도 이 게이트에 걸려
`—`로 보인다 — §3이 정의한 진행 중 par-only 상태(정상)가 표시 층에서는 레거시
par-only 상태(비정상)와 구분되지 않는다. 영향은 작다: 현재 홀의 파는 카운터 페이지와
링에 이미 떠 있고, 스코어카드 페이지는 아래로 스와이프해야 보인다. 정규화가 이미
현재 홀을 예외 없이 다루므로(§5.2) 별도 분기를 추가하지 않는다.
```

- [x] **Step 2: 커밋** — `92c3808 📝 docs: ScoringView가 진행 중인 현재 홀도 §6 게이트에 걸리는 부수 효과 명시`

---

## 최종 코드 리뷰

`requesting-code-review` 스킬로 A~D 전체 diff(`9dfc2b1..92c3808`)를 리뷰(Opus). 결과:

- **Critical:** 없음
- **Important:** Task C가 절반만 적용됨 — 위 Task C Step 3~4로 해소
- **Minor (수용, 후속 없음):**
  - `isSaveable`의 doc이 실제 구현보다 좁게 서술됨 (동작엔 영향 없음)
  - `apply(to:holeIndex:)`가 `isSaveable`을 실제로 강제하진 않음 — 저장 버튼의 `.disabled()`가 여전히 유일한 방어선. 이론상으로만 도달 가능(파 선택지에 0이 없고, `par == 0 && score > 0`는 이미 상위에서 불가능)이라 이번엔 놔둠
  - Task B의 새 테스트가 만드는 상태(중간 par-only 홀)는 실제 UI 플로우로는 도달 불가능(`goToNextHoleOrConfirm()`이 항상 건너뛰기 다이얼로그로 가로챔) — 회귀 방지용으로 의도적으로 우회했다는 주석은 남기지 않음
  - Task D가 이전 홀 버튼 케이스(§4.2)는 언급 안 함 — 현재 홀 케이스만 다뤘어도 틀린 설명은 아님

**Ready to merge: Yes** (Important 해소 후)

## 완료 조건

- `HoleEditSheet`의 doc comment("불변식은 전부 RoundEditViewModel이 강제한다")가 구조적으로 참이 됨
- 정규화된 홀이 배열 중간에 남는 케이스와 `finishRound()`의 실제 발행값이 테스트로 고정됨
- PR #21의 blast-radius 안에서 `spec §N`이 가리키는 문서가 전부 명시적임
- `ScoringView`의 표시 부수 효과가 스펙에 기록되어 향후 버그로 오인되지 않음
- 세 타깃 빌드 성공, iOS·워치 테스트 전부 통과, `make lint`·`make format` 위반 0
