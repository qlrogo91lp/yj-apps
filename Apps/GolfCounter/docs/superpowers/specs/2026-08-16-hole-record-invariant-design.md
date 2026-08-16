# 홀 기록 불변식 — par-only 홀 제거 설계

작성일: 2026-08-16
참조 스펙: `2026-08-13-ios-history-stats-design.md` §3 (용어와 공통 계산 규칙 — 이 문서가 §3을 정정한다)
선행 작업: [PR #20](https://github.com/qlrogo91lp/golf_counter/pull/20) `2026-08-16-common-relative-to-par-aggregation.md` (오버파 집계에서 미타구 홀 제외, merged)
대응 plan: `2026-08-16-common-hole-record-invariant.md` (미작성)

## 1. 배경 — PR #20이 남긴 것

PR #20은 **파는 골랐지만 한 타도 치지 않은 홀**(이하 **par-only 홀**, `par > 0 && score == 0`)이 오버파 합계에 `0 − par`로 새어 들던 버그를 고쳤다. 계산을 `ScoreAggregate.relativeToPar`로 모으고 집계 대상 홀(`par > 0 && score > 0`)만 더하게 했다.

그런데 **고친 것은 합계뿐이다.** par-only 홀은 여전히 만들어지고, 화면 여기저기에 그 홀이 각기 다른 방식으로 새어 나온다. PR #20의 최종 리뷰가 이 중 첫 번째를 지적했고, 이 문서는 세 가지를 전부 다룬다.

## 2. 문제 — 세 가지 어긋남

### 2.1 홀 행과 합계가 서로 다른 말을 한다

par-only 홀에서 개별 홀 행은 `score − par`를 그대로 그린다. 게이트가 `par > 0` 하나뿐이기 때문이다.

| 화면 | 파일 | 홀 행 표시 | 바로 아래 합계 |
|------|------|-----------|--------------|
| 워치 스코어카드 | `WatchApp/Features/Round/Scorecard/ScorecardView.swift:21` | `H8  Par4  0타(0p)  -4` | 그 홀 제외 |
| iOS 라운드 상세 | `iOSApp/Features/History/Detail/Components/HoleRow.swift:11,30` | `H3  Par 4  0타 · 0퍼트  -4` | 그 홀 제외 |

iOS 쪽은 `ScorePalette`가 언더파 색까지 입혀 버디처럼 보인다.

PR #20 이전에는 행도 합계도 똑같이 틀려서 **일관되게 틀렸다**. 지금은 합계만 고쳐져 **서로 모순된다.** 사용자가 실제로 신고하는 형태다 — "8번 홀은 −4인데 합계는 왜 안 움직여?"

### 2.2 기록 홀 수와 오버파가 다른 홀 집합을 본다

`recordedHoleCount`는 **유효 홀**(`par > 0`) 개수라 par-only 홀을 센다. 오버파는 집계 대상 홀만 본다. 그래서 `18홀` 뱃지가 붙은 라운드의 오버파가 17홀치가 된다.

스펙 §3이 유효 홀 ≠ 집계 대상 홀이라고 구분해 두긴 했지만, 워치의 `skipCurrentHole()` 주석은 오히려 **이 어긋남을 결함으로 보고 파를 지운다**고 적혀 있다 (`WatchApp/Features/Round/RoundViewModel.swift:269-272`):

> 파를 남긴 채 넘어가면 그 홀이 기록 홀 수에 잡히고, 오버파에서는 집계 대상 홀이 아니라 빠져서 "18홀인데 17홀치 스코어"라는 어긋남이 생긴다. 파를 지우면 두 지표가 같은 홀 집합을 보게 된다.

즉 **코드는 이미 "par-only 홀은 존재하면 안 되는 상태"라는 입장을 취하고 있는데, 그 입장이 한 경로에만 적용돼 있다.**

### 2.3 종료 확인 다이얼로그가 거짓말을 한다

`RoundSessionView.swift:68`의 문구는 `recordedHoleCount`를 쓴다 — "8홀이 기록됩니다". 그 8홀 중 하나가 par-only면 실제 전송되는 스코어는 7홀치다.

## 3. 불변식 (이 설계의 핵심)

> **저장·전송되는 모든 홀은 `par > 0 && score > 0`(기록된 홀)이거나 `par == 0 && score == 0`(기록 없는 홀)이다.**
> 즉 `(par > 0) == (score > 0)`.

**"저장·전송되는"이 불변식의 범위다.** 라운드 진행 중에는 par-only 홀이 **정상 상태다** — 파 선택 화면이 카운터보다 먼저 오므로, 새 홀에 들어가 파를 고른 직후부터 첫 타를 칠 때까지 모든 홀이 반드시 그 상태를 거친다. 이걸 금지하면 입력 흐름 자체가 성립하지 않는다.

그래서 이 설계는 **입력을 막지 않고 경계에서 정규화한다.** 경계는 셋이다 — 워치의 홀 이동, 워치의 라운드 종료(전송 직전), iOS 편집 시트의 저장. 그 경계를 넘는 순간 par-only 홀은 "기록 없는 홀"로 되돌아간다. 첫 번째는 PR #17이 이미 구현했고(§4.3), 이 설계는 나머지 둘을 같은 규칙으로 맞춘다.

네 조합 중 경계 밖에서 유효한 것은 두 개다.

| par | score | 상태 | 지금 |
|-----|-------|------|------|
| `> 0` | `> 0` | 기록된 홀 | 유효 |
| `== 0` | `== 0` | 기록 없는 홀(건너뜀 / 미진입) | 유효 |
| `== 0` | `> 0` | 해석 불가 | **이미 불가능** — 파 선택 화면이 카운터보다 먼저 오고, `skipCurrentHole()`이 타수 있는 홀을 거부한다 |
| `> 0` | `== 0` | par-only 홀 | **경계에서 정규화한다** (진행 중에는 정상) |

이 불변식이 서면 스펙 §3의 **유효 홀과 집계 대상 홀이 같은 집합이 된다.** 두 개념을 분리해 둘 이유가 사라지므로 §3을 정정한다(§7).

불변식은 두 층위로 지킨다. 하나면 충분해 보이지만 막는 것이 다르다.

1. **경계 정규화** — 저장·전송을 넘는 par-only 홀을 "기록 없는 홀"로 되돌린다 (§5). 앞으로 들어오는 데이터를 책임진다
2. **표시 방어** — 그래도 새어 든 것을 화면이 잘못 그리지 않게 한다 (§6). 이미 저장된 레거시 데이터를 책임진다

## 4. par-only 홀이 생기는 경로 — 전수 조사

### 4.1 워치 · 종료 (열려 있음)

새 홀에서 파를 고르면 카운터가 열린다. 한 타도 치지 않은 채 **라운드를 종료**하면 그 홀이 `par = N, score = 0`으로 남는다.

`RoundSnapshot.trimmed()`는 배열 **말단의 `par == 0` 홀만** 잘라낸다(`Shared/Models/RoundSnapshot.swift:44`). par-only 홀은 `par > 0`이라 트림을 통과해 iOS로 전송된다.

### 4.2 워치 · 이전 홀 버튼 (열려 있음)

카운터에 이전 홀 버튼이 있다(`WatchApp/Features/Round/Counting/CountingView.swift:69` → `goToPreviousHole()`).

1. 홀 8에서 파 4를 고른다 → 카운터 (score 0)
2. 이전 버튼 → 홀 7로 간다. **홀 8은 `par 4 / score 0`으로 배열에 남는다**
3. 홀 7에서 종료 → 홀 8은 현재 홀이 아니다

**정규화 대상을 "현재 홀"로 좁히면 이 경로를 놓친다.** 설계 초안이 실제로 이 실수를 했고, 코드를 확인하면서 잡았다. 정규화는 **모든 홀**을 대상으로 해야 한다.

### 4.3 워치 · 다음 홀 버튼 (이미 막혀 있음)

PR #17이 막았다. `goToNextHoleOrConfirm()`이 `currentScore == 0`이면 건너뛰기 다이얼로그를 띄우고, `skipCurrentHole()`이 파를 0으로 되돌린 뒤 이동한다(`CountingView.swift:54`, `RoundViewModel.swift:277`).

**이 경로가 이번 설계의 선례다** — 나머지 경로를 같은 규칙으로 맞추는 것이 이 작업의 전부다.

### 4.4 iOS · 홀 편집 시트 (열려 있음)

저장 버튼은 파 선택 여부만 검사한다(`iOSApp/Features/History/Detail/Components/HoleEditSheet.swift:59`). 두 방향 모두 par-only 홀을 만든다.

- 건너뛴 홀(`par == 0`)을 탭해 파만 고르고 타수 0인 채 저장
- 기록된 홀의 타수를 0까지 내려 저장 (`decrementScore()`는 `putts`가 0이면 0까지 내려간다)

### 4.5 레거시 데이터

위 경로로 이미 저장된 라운드가 SwiftData에 있을 수 있다. 정규화는 앞으로 들어오는 데이터만 다루므로 **레거시는 표시 방어(§6)와 기록 홀 수 정의 변경(§7)이 커버한다.** 마이그레이션은 두지 않는다 — `relativeToPar`·`recordedHoleCount`가 모두 계산 프로퍼티라 정의만 바꾸면 기존 라운드도 즉시 올바른 값을 보인다.

## 5. 정규화 설계

### 5.1 워치 — 시점을 "종료 확인 **후**"로 잡는 이유

정규화 시점 후보는 둘이었다.

**후보 A: 종료 버튼을 누른 시점 (다이얼로그 뜨기 전)** — 기각.

`phase`는 `currentPar == 0`이면 파 선택 화면을 띄운다(`RoundViewModel.swift:96`). 현재 홀의 파를 다이얼로그 전에 지우면, 사용자가 **"취소"를 눌렀을 때 카운터가 아니라 파 선택 화면으로 튕긴다.** 종료를 무른 것뿐인데 홀이 초기화된 것처럼 보인다. 취소 시 되돌리는 로직을 넣어 막을 수는 있지만, 그 복잡도를 살 이유가 없다.

**후보 B: 종료 확인 후 (`finishRound()` 안) — 채택.**

취소 부작용이 원천적으로 없다. 대신 다이얼로그 문구가 정규화 **전**의 상태를 보게 되는데, 이건 `recordedHoleCount`의 정의를 집계 대상 홀 기준으로 바꾸면(§7) 자동으로 해결된다 — 정규화 여부와 무관하게 항상 "실제로 점수가 있는 홀 수"를 세기 때문이다.

즉 **정규화는 데이터를 정리하고, 정의 변경은 표시를 정확하게 만든다.** 두 장치가 각자의 일을 한다.

### 5.2 워치 — 어디에 놓는가

배열을 소유하는 `HoleProgress`에 정규화 메서드를 둔다. `skipCurrentHole()`이 `progress.setPar(0)`을 호출하는 것과 같은 계층이다.

```swift
// HoleProgress
/// 파는 있는데 한 타도 치지 않은 홀의 파를 지워 "기록 없는 홀"로 되돌린다.
/// `skipCurrentHole()`이 홀 이동 경로에서 현재 홀 하나에 하는 일을,
/// 종료 시점에 남아 있는 모든 홀에 대해 한다 (spec §5.2).
mutating func clearUnplayedHoles()
```

`RoundViewModel.finishRound()` 첫머리에서 호출한다. `finishRound()`는 `isFinished = true`로 요약 화면을 띄우므로, **정규화가 그보다 먼저 일어나야 요약 헤더가 정리된 값을 본다.**

정규화 후 스냅샷을 발행한다(`publishSnapshot()`). `skipCurrentHole()`도 같은 이유로 발행한다 — 상태가 실제로 바뀌었고, App Group 스냅샷은 컴플리케이션과 크래시 복구의 데이터원이다. 발행하지 않으면 종료와 전송 사이에 크래시가 났을 때 정규화 이전 상태로 복구된다.

### 5.3 워치 — 정규화 후 어떻게 되는가

정규화된 홀은 `par == 0 && score == 0`이 되어 기존 규칙에 그대로 흡수된다.

- **말단이면** `trimmed()`가 배열에서 제거한다 → 전송 배열이 짧아진다
- **중간이면** `par == 0`으로 남아 "건너뛴 홀"로 전송된다 → iOS가 `기록 없음`으로 표시하고, 탭해서 복구할 수 있다

두 경로 모두 이미 정의되고 테스트된 동작이다. **정규화는 새 상태를 만들지 않고, 기존의 유효한 상태로 되돌릴 뿐이다.** 이 설계에서 가장 중요한 성질이다.

전체 라운드가 par-only인 극단(파만 고르고 한 타도 안 침)에서는 모든 파가 0이 되고 `trimmed()`가 전부 잘라내 `recordedHoleCount == 0`이 된다. 그러면 `saveAndTransmit()`의 0홀 가드(`RoundViewModel.swift:179`)가 전송 없이 스냅샷만 지운다 — "iOS에 빈 라운드를 만들지 않는다"(스펙 §2 결정 10)와 정확히 맞는 결과다.

### 5.4 iOS — 편집 저장 시 정규화

`RoundEditViewModel.apply(to:holeIndex:)`에서 타수가 0이면 파도 0으로 쓴다.

```swift
pars[holeIndex] = score > 0 ? par : 0
```

이 한 줄이 §4.4의 두 방향을 모두 막는다. 그리고 **"이 홀은 사실 안 쳤다"를 되돌리는 구제 경로**가 된다 — 라운드가 끝난 뒤 워치 오기록을 고칠 수 있는 유일한 지점이므로 이 기능은 살려 둔다.

시트에 별도 안내 문구는 두지 않는다. 저장 직후 상세 화면의 그 행이 `기록 없음`으로 바뀌어 결과가 즉시 보이기 때문이다 (YAGNI).

### 5.5 채택하지 않은 것 — iOS 수신측 방어

`RoundImporter`가 수신 메시지를 정규화하는 방안은 두지 않는다. 워치가 전송 전에 정규화하므로 정상 경로에서는 도달하지 않고, 구버전 워치와의 스큐는 표시 방어(§6)가 이미 커버한다. v1 리빌드 중이라 배포된 구버전도 없다.

## 6. 표시 방어

두 뷰의 게이트를 `par > 0`에서 `par > 0 && score > 0`으로 바꾼다.

| 파일 | 지금 | 바꾼 뒤 |
|------|------|--------|
| `iOSApp/.../HoleRow.swift:11` | `isRecorded = par > 0` | `isRecorded = par > 0 && score > 0` |
| `WatchApp/.../ScorecardView.swift:16,21` | Par 칸·오버파 칸이 각각 `row.par > 0` | 두 칸 모두 같은 조건으로 |

표시는 par-only 홀을 **건너뛴 홀과 똑같이** 다룬다 — iOS는 `Par – / 기록 없음`, 워치는 `—`와 빈 오버파 칸. 화면에 "기록 없는 홀" 상태가 하나만 존재하게 된다.

행을 탭하면 편집 시트는 여전히 **저장된 파를 보여준다.** 표시상 `기록 없음`이어도 데이터는 남아 있으므로, 사용자가 타수를 넣어 정상 홀로 복구할 수 있다. 표시 방어가 수정 경로를 막지 않는다는 뜻이다.

§5의 정규화가 서면 새 데이터는 이 분기에 걸리지 않는다. **이 방어는 레거시 데이터와 미래의 누수를 위한 것이고, 정규화의 대체재가 아니다.**

## 7. 기록 홀 수 정의 정정

### 7.1 무엇을 바꾸는가

`recordedHoleCount`를 **집계 대상 홀**(`par > 0 && score > 0`) 기준으로 바꾼다. `relativeToPar`와 **정확히 같은 필터**를 쓰게 되므로, 두 지표가 같은 홀 집합을 본다는 사실이 코드에 드러난다.

`relativeToPar`가 그랬듯 이 값도 두 타입이 중복 정의하고 있다(`Shared/Models/RoundSnapshot.swift:63`, `Shared/Persistence/GolfRound.swift:41`). PR #20과 같은 패턴으로 `ScoreAggregate`에 모은다.

```swift
enum ScoreAggregate {
    static func relativeToPar(holeScores: [Int], holePars: [Int]) -> Int      // 기존
    static func recordedHoleCount(holeScores: [Int], holePars: [Int]) -> Int  // 신규
}
```

### 7.2 파급 범위

| 사용처 | 파일 | 바뀌는 것 |
|--------|------|----------|
| 워치 종료 다이얼로그 문구 | `RoundSessionView.swift:68` | "8홀" → "7홀" (정확해짐) |
| 워치 요약 헤더 | `SummaryView.swift` | 같음 |
| 워치 0홀 가드 | `RoundViewModel.swift:179` | par-only만 있는 라운드를 빈 라운드로 처리 (개선) |
| 워치 요약 버튼 라벨 | `SummaryView.swift:79` | 위 가드와 같은 조건 |
| iOS 리스트 뱃지 | `RoundCard.swift` | `N홀`이 실제 점수가 있는 홀 수 |
| iOS 18홀 판정 | `GolfRound.isFullRound` | 18홀 **전부 점수가 있는** 라운드만 해당 |

`isFullRound`는 통계(plan ⑥)의 총타수 기반 집계 대상을 가른다. 점수가 빠진 홀이 있는 라운드가 "18홀 라운드"로 잡히면 총타수 통계가 왜곡되므로, 이 변경은 ⑥에 유리하다.

### 7.3 스펙 §3 정정

`2026-08-13-ios-history-stats-design.md` §3을 다음과 같이 고친다.

- **불변식을 새 항목으로 추가** — `(par > 0) == (score > 0)`, 그리고 이것이 어디서 강제되는지
- **기록 홀 수**: "유효 홀의 개수" → "집계 대상 홀의 개수". `ScoreAggregate.recordedHoleCount`로 파생한다고 명시
- **유효 홀 / 집계 대상 홀**: 불변식 하에서 두 집합이 같아진다는 점을 명시. 용어는 남기되(레거시 데이터를 설명할 때 여전히 필요), 지표 계산에는 집계 대상 홀만 쓴다고 못 박는다

§3의 오버파 항목은 PR #20이 이미 정정했으므로 그대로 둔다.

## 8. 파일별 변경

| 파일 | 변경 |
|------|------|
| `Shared/Models/ScoreAggregate.swift` | `recordedHoleCount(holeScores:holePars:)` 추가 |
| `Shared/Models/RoundSnapshot.swift` | `recordedHoleCount`를 `ScoreAggregate` 호출로 교체 |
| `Shared/Persistence/GolfRound.swift` | 같음 |
| `WatchApp/Features/Round/HoleProgress.swift` | `clearUnplayedHoles()` 추가 |
| `WatchApp/Features/Round/RoundViewModel.swift` | `finishRound()`에서 정규화 + 스냅샷 발행 |
| `WatchApp/Features/Round/Scorecard/ScorecardView.swift` | 행 게이트를 `par > 0 && score > 0`으로 |
| `iOSApp/Features/History/Detail/Components/HoleRow.swift` | `isRecorded` 게이트 같음 |
| `iOSApp/Features/History/Detail/RoundEditViewModel.swift` | `apply(to:holeIndex:)`에서 `score == 0`이면 par도 0 |
| `docs/superpowers/specs/2026-08-13-ios-history-stats-design.md` | §3 정정 (§7.3) |

`Shared/`는 `PBXFileSystemSynchronizedRootGroup`이고 새 파일도 없으므로 pbxproj는 손대지 않는다.

## 9. 테스트

| 대상 | 케이스 |
|------|--------|
| `ScoreAggregateTests` | `recordedHoleCount` — par-only 제외 / `par == 0` 제외 / 배열 길이 불일치 / 빈 배열 |
| `HoleProgressTests` | `clearUnplayedHoles()` — 현재 홀만 par-only / **이전 버튼으로 두고 온 홀**(§4.2) / 여러 홀 혼재 / 정상 홀은 안 건드림 |
| `RoundViewModelHoleFlowTests` | 종료 시 정규화된 뒤 전송되는지 / 정규화가 말단이면 `trimmed()`가 제거하는지 / 전부 par-only면 0홀 경로로 가는지 |
| `RoundEditViewModelTests` | 타수 0 저장 시 par도 0 / 타수 1 이상이면 par 유지 |
| `RoundSnapshotTests` · `GolfRoundTests` | `recordedHoleCount` 회귀 (par-only 홀이 안 세어지는지) |

기존 테스트 중 `recordedHoleCount`가 par-only 홀을 세기를 기대하는 것이 있으면 **그 테스트가 지금 상태를 고정하고 있었다는 뜻이므로, 고치기 전에 보고한다.**

## 10. 범위 밖

- 종료 다이얼로그·요약·시트의 **문구와 레이아웃** — 숫자와 분기만 정확해지고 UI는 그대로다
- 스코어카드 레이아웃
- 레거시 데이터 마이그레이션 (§4.5 — 계산 프로퍼티라 불필요)
- `totalStrokes` · `totalPutts` · `totalPar` — 필터 없는 원시 합계로 유지한다(PR #20의 결정 그대로). `totalStrokes − totalPar`가 `relativeToPar`와 다를 수 있고 그것이 의도다. **plan ⑥의 평균 오버파는 반드시 `ScoreAggregate`를 쓰고 이 뺄셈으로 재유도하지 않는다**
- 워치 이전 홀 버튼의 동작 변경 — par-only 홀을 만드는 경로지만, 되돌아갈 자유는 유지하고 정규화로 뒤처리한다

## 11. 후속

이 작업은 **plan ⑥(통계 탭)보다 먼저** 끝낸다. ⑥의 평균 오버파와 18홀 판정이 여기서 정하는 `ScoreAggregate` 규칙과 `isFullRound` 정의를 그대로 물려받는다.
