# 카운팅 화면 UX 후속 정리 (watch)

## 1. 무엇을 바꾸나

시뮬레이터 실기 검토에서 발견한 카운팅/요약 화면의 UX 문제 네 가지를 고친다.

1. **Undo가 홀을 옮기면 사라진다.** 히스토리를 홀 단위로 보관해, 이전 홀로 돌아오면 그 홀의
   되돌리기가 살아나게 한다.
2. **마지막 홀에도 `›`가 떠 있다.** 갈 곳이 없는데 활성 상태처럼 보인다 — 마지막 홀에서는
   종료 진입점으로 바꾼다.
3. **요약 화면의 "저장 안 함"이 텍스트 버튼이라 눌리는지 알 수 없다.** 두 버튼 모두 실제
   버튼으로 만들고, 표시 정보를 총타수 중심으로 정리한다.

## 2. 배경

`docs/superpowers/specs/2026-08-11-watch-counter-redesign-design.md` §7이 undo 모델을
"현재 홀 스코프"로 정의하면서, 홀을 옮기면 히스토리를 지우는 것까지 그 스코프의 일부로
묶었다. 실기로 써보니 이 둘은 별개다 — "되돌리기 대상은 지금 보는 홀"이라는 의미는
유지하고 싶지만, 그 홀을 잠깐 벗어났다 왔다고 기록 자체가 사라질 이유는 없다.

`CountingView`의 `chevron.right`는 `isEnabled`를 넘기지 않아(기본값 `true`) 마지막 홀에서도
항상 활성으로 보이는 죽은 버튼이었다 — `goToNextHoleOrConfirm()`이 `canGoToNextHole`로
조용히 막고 있을 뿐이다.

`SummaryView`의 "저장 안 함"은 `.buttonStyle(.plain)` + secondary 색으로, 탭 가능한
컨트롤인지 시각적으로 구분되지 않는다. 상단의 "N홀 완료" 헤드라인과 `courseName` 표시
블록은 화면의 주인공(오버파)보다 먼저 눈에 들어오면서도 `courseName`은 워치에서 한 번도
설정되지 않는 죽은 코드다(`HomeViewModel`이 넘기지 않음).

## 3. 확정한 설계 결정

1. **Undo 히스토리는 홀별로 보관한다.** "지금 보는 홀의 마지막 입력만 되돌린다"는 스코프는
   그대로 두되, 그 히스토리의 수명을 라운드 전체로 늘린다.
2. **홀을 옮겨도 히스토리를 지우지 않는다.** `resetHoleLocalState()`에서 undo clear를 뺀다.
   phantom hole 제거 경로(`cancelToPreviousHole()`)는 별도 정리가 필요 없다 — `incrementStroke()`와
   `undo()`가 항상 짝을 이뤄 동작해 `currentScore == 0`인 홀은 애초에 히스토리가 있을 수
   없고, phantom hole 조건 자체가 `currentScore == 0`을 요구하므로 그 홀의 히스토리는
   제거 시점에 이미 비어 있음이 보장된다.
3. **복구 라운드는 여전히 undo 불가.** `init(resuming:)`은 히스토리가 없는 상태로
   시작한다 — 되돌릴 대상을 모르는 채로 되돌리는 것보다 안전하다는 기존 근거를 유지한다.
4. **마지막 홀의 `›` 자리는 종료 버튼(`flag.checkered`)으로 바뀐다.** 누르면 기존 종료
   확인 다이얼로그(`RoundSessionView`가 소유)가 뜬다. 컨트롤 페이지의 종료 진입점은
   그대로 둔다 — 마지막 홀 전에도 언제든 끝낼 수 있어야 한다.
5. **요약의 두 버튼을 가로 2등분한 진짜 버튼으로 만든다.** "저장"(`.borderedProminent`
   green) / "버리기"(`.bordered`). 라벨은 "저장"으로 축약한다(전송이라는 단어는 필요 없다).
6. **요약 표시 정보는 총타수를 주인공으로 삼는다.** 큰 숫자를 총타수로 바꾸고 옆에
   오버파 배지를 붙인다. 그 아래 "N홀 · N퍼트" 한 줄. "N홀 완료" 헤드라인과 `courseName`
   표시 블록은 제거한다.
7. **전송 중에는 "버리기"를 숨기고 "저장" 버튼이 전폭으로 늘어난다.** 대기 중이던 전송이
   취소될 수 있는 상태라 반쪽 버튼으로 남겨두면 혼선을 준다(기존 동작 유지).
8. **0홀(기록 없음)은 큰 숫자 없이 안내 문구 한 줄 + 전폭 버튼 하나.** 기존 문구
   "저장 없이 종료"를 그대로 쓴다.

## 4. Undo 모델 변경

### 현재 구조 (spec §7)

```swift
struct StrokeUndo: Equatable {
    private(set) var history: [StrokeInputMode] = []
    var canUndo: Bool { !history.isEmpty }
    mutating func record(_ mode: StrokeInputMode)
    mutating func pop() -> StrokeInputMode?
    mutating func clear()
}
```

`RoundViewModel`이 홀을 옮길 때마다 `resetHoleLocalState()`에서 `undoStack.clear()`를 불러
히스토리를 통째로 버린다.

### 바뀌는 구조

`StrokeUndo`가 홀 인덱스별로 히스토리를 나눠 갖는다. 타입은 하나로 유지하고(한 파일 = 한
타입), 저장소만 `[Int: [StrokeInputMode]]`로 바꾼다.

```swift
struct StrokeUndo: Equatable {
    private var historyByHole: [Int: [StrokeInputMode]] = [:]

    func history(forHole hole: Int) -> [StrokeInputMode]
    func canUndo(hole: Int) -> Bool
    mutating func record(_ mode: StrokeInputMode, hole: Int)
    mutating func pop(hole: Int) -> StrokeInputMode?
}
```

`RoundViewModel`의 호출부(`incrementStroke()` / `undo()` / `canUndo` 게터)가 현재 홀
인덱스를 같이 넘긴다. `resetHoleLocalState()`는 `inputMode` 리셋과 `isEditingPar` 취소만
남고 undo clear는 빠진다. `cancelToPreviousHole()`의 phantom hole 제거 경로도 그대로 —
위 근거대로 정리할 대상이 없다.

### 왜 홀 단위 Dictionary인가

배열(`[[StrokeInputMode]]`, 인덱스 = 홀)도 가능하지만, `HoleProgress`처럼 홀 배열 3개의
길이를 맞추는 불변식을 새로 하나 더 만들게 된다. `StrokeUndo`는 `HoleProgress`와 별개
타입으로 계속 독립적이어야 하므로(관심사 분리), 길이 동기화가 필요 없는 `Dictionary`가
더 단순하다. 존재하지 않는 홀 인덱스를 조회하면 자연히 빈 배열(`canUndo == false`)로
처리되어 `HoleProgress`의 현재 배열 상태와 별도로 안전하다.

## 5. 마지막 홀 종료 버튼

`CountingView.ringArea`의 `HoleArrowButton(systemName: "chevron.right", ...)` 자리를
`viewModel.canGoToNextHole` 여부로 분기한다.

- `canGoToNextHole == true`: 기존과 동일(`chevron.right`, `goToNextHoleOrConfirm`).
- `canGoToNextHole == false`: `flag.checkered` 아이콘, 항상 활성, 누르면 종료 확인
  다이얼로그를 띄운다.

다이얼로그 자체(제목·문구·`endRound()` 호출)는 `RoundSessionView`가 계속 소유한다.
`CountingView`는 "종료를 요청한다"는 콜백만 상위로 올린다.

```
RoundSessionView (isConfirmingEnd, endRound 소유)
  └─ ScoringView(onRequestEnd: { isConfirmingEnd = true })
       └─ CountingView(onRequestEnd: ...)
```

마지막 홀 판정은 `viewModel.canGoToNextHole`로 이미 존재하는 값을 그대로 쓴다 — 별도
"마지막 홀" 플래그를 새로 만들지 않는다.

## 6. 요약 화면 레이아웃

```
        72  +3        총타수 42pt bold rounded / 오버파 17pt semibold, 옆에 배지처럼
      18홀 · 32퍼트    13pt secondary

   [ 버리기 ] [ 저장 ]  가로 2등분, 각 38pt 높이
```

- 총타수: `viewModel.trimmedTotalStrokes`, 오버파: `ScoreFormat.relativeToPar(trimmedRelativeToPar)` —
  기존과 같은 트림 후 값을 쓴다.
- "N홀 · N퍼트" 한 줄: `recordedHoleCount`(집계 대상 홀 수) + `trimmedTotalPutts`. 기존
  "summary_strokes_putts"("%lld타 · %lld퍼트")를 대체하는 새 문자열
  "summary_holes_putts"("%lld홀 · %lld퍼트")가 필요하다 — 타수는 이미 위 큰 숫자에 있으므로
  중복 표기하지 않는다.
- 버튼: `HStack`으로 "버리기"(`.bordered`) / "저장"(`.borderedProminent`, tint green)
  가로 2등분. 각각 `viewModel.discardRound`(확인 다이얼로그 경유) / `viewModel.saveAndTransmit`에
  연결 — 기존 로직·다이얼로그는 그대로 재사용한다.
- **전송 중** (`viewModel.isTransmitting`): "버리기"를 숨기고 "저장" 버튼이 전폭으로 늘어나며
  라벨이 "전송 중…"으로 바뀐다(기존 `summary_transmitting` 재사용).
- **0홀** (`recordedHoleCount == 0`): 큰 숫자·오버파·홀/퍼트 줄을 전부 숨기고 안내 문구
  ("summary_holes_empty", 기존 재사용) 한 줄만 남긴다. 버튼도 "저장 없이 종료"
  (`round_end_confirm_empty` 재사용) 전폭 버튼 하나로 바뀐다 — "버리기"는 뜨지 않는다
  (기록이 없으면 버릴 것도 없다).
- 헤드라인 "N홀 완료"(`summary_holes_completed`)와 `courseName` 표시 블록은 제거한다.

### 문자열 변경

| 키 | ko | en | 상태 |
|---|---|---|---|
| `summary_save` | "저장" | "Save" | 신규 |
| `summary_holes_putts` | "%lld홀 · %lld퍼트" | "%lld holes · %lld putts" | 신규 |
| `summary_discard_button` | "버리기" | "Discard" | 값 변경(기존 "저장 안 함") |
| `summary_strokes_putts` | — | — | 삭제 |
| `summary_holes_completed` | — | — | 삭제 |

`StringsParityTests`가 ko/en 키 집합 일치와 포맷 지정자 일치를 검증하므로 두 `.lproj` 모두
수정한다.

## 7. 파일 변경

### 재작성

- `WatchApp/Features/Round/StrokeUndo.swift` — 홀 인덱스 기반 저장소로 확장
- `WatchApp/Features/Round/Summary/SummaryView.swift` — §6 레이아웃

### 수정

- `WatchApp/Features/Round/RoundViewModel.swift` — undo 호출부에 홀 인덱스 전달,
  `resetHoleLocalState()`에서 clear 제거
- `WatchApp/Features/Round/Counting/CountingView.swift` — 마지막 홀 종료 버튼,
  `onRequestEnd` 파라미터
- `WatchApp/Features/Round/ScoringView.swift` — `onRequestEnd` 콜백 통과
- `WatchApp/Features/Round/RoundSessionView.swift` — `centerPage`에 `onRequestEnd` 주입
- `WatchApp/ko.lproj/Localizable.strings`, `WatchApp/en.lproj/Localizable.strings` — §6 문자열

### 테스트 갱신

- `watchosTests/Round/StrokeUndoTests.swift` — 홀 인덱스 파라미터 반영, "다른 홀은
  서로 독립" 케이스 추가
- `watchosTests/Round/RoundViewModelUndoTests.swift` — 기존 두 "이동하면 되돌릴게 없다"
  테스트는 유지(이동 *직후* 홀은 기록이 없는 새 홀이라 여전히 참이다). 이번 버그의
  실제 시나리오 — 기록이 있는 홀을 떠났다가 돌아오면 undo가 살아있는지 — 를 검증하는
  새 케이스를 추가한다

## 8. 범위 밖

- `RoundSnapshot` 스키마 변경 — 복구 후 undo는 여전히 비활성 상태를 유지한다(§3.3).
- 컨트롤 페이지의 종료 진입점 제거 — 마지막 홀 전에도 종료할 수 있어야 하므로 유지.
- `viewModel.courseName` 프로퍼티 자체 삭제 — 스냅샷·전송 페이로드에는 계속 쓰인다.
  요약 화면의 **표시** 블록만 제거한다.
- 워크아웃 메트릭(칼로리·시간 등)을 요약에 노출하는 것 — 기존처럼 전송 페이로드에만
  싣고 iOS 상세 화면이 보여주는 구조를 유지한다.
