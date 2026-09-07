# 파 선택 화면 레이아웃 재설계 (watch)

## 1. 무엇을 바꾸나

`ParSelectionView`가 작은 워치에서 잘린다. 원인은 세로 요구량이 예산을 넘는데 전부 고정
높이라 줄어들 여지가 없다는 것이다. 세 par 버튼을 `ScrollView`에 넣어 초과분을 스크롤로
흡수하고, 맨 아래 전폭을 차지하던 "이전" 버튼을 헤더 라인의 원형 버튼으로 올린다.

**원탭 즉시 선택은 유지한다.** Select + Confirm 2단계는 검토했으나 기각했다 (§7).

## 2. 배경 — 왜 잘리나

현재 `ParSelectionView`의 세로 요구량은 전부 고정값이다.

| 요소 | 높이 |
|---|---|
| 헤더 `H7` (15pt 폰트) | ~18 |
| `ParOptionButton` × 3 (`minHeight: 46`) | 138 |
| `ParBackButton` (`minHeight: 30`) | 30 |
| `VStack(spacing: 6)` × 4 | 24 |
| **합계** | **~210pt** |

이 화면은 `RoundSessionView`의 가로 `TabView(.page)` 안에 있다. 상단 시스템 크롬과 하단
페이지 점 인디케이터를 빼고 나면 세로 예산은 40mm에서 **150pt 안팎**, 46mm에서 **190pt
안팎**이다(실측으로 확정). 어느 쪽이든 210pt는 들어가지 않으며, 고정 높이 `VStack`은
초과분을 잘라낸다.

같은 문제를 `CountingView`는 `Spacer` + `ViewThatFits` 3단 크기 세트로 푼다. 파 선택
화면에는 그 장치가 없다.

## 3. 확정한 설계 결정

1. **원탭 즉시 선택을 유지한다.** Confirm 2단계는 홀당 탭 1회(18홀 = 18탭)를 추가하는
   대가로 오터치를 막는데, 이번 재설계의 동기는 오터치가 아니라 공간 부족이었다.
   오선택 교정 경로도 이미 있다 — 카운터 헤더의 `Par` 버튼(`beginParEditing()`).
2. **세로 3행 배치를 유지하고 `ScrollView`로 감싼다.** 가로 3타일 배치도 검토했으나(§7),
   전폭 행이 탭 정확도가 높고 현재 구조에서 변경 폭이 작다.
3. **헤더는 `ScrollView` 밖에 고정한다.** 안에 넣으면 스크롤 시 백버튼이 화면 밖으로
   밀려 §4의 탈출 경로가 사라진다.
4. **백버튼은 헤더 라인의 원형 버튼으로 올린다.** 전용 `ParBackButton`을 삭제하고
   `CircleIconButton`을 쓴다.
5. **재편집 중 백버튼은 "편집만 닫고 카운터 복귀"다.** 이전 홀로 이동하지 않는다 (§5).

## 4. 백버튼을 없애지 않는 이유

이 화면은 두 경로로 뜬다 — ① 새 홀 최초 진입(`par == 0`), ② 카운터의 `Par` 버튼 재편집.
①에서 백버튼은 phantom hole의 **유일한 탈출 경로**다.

7홀 카운팅 중 `›`를 잘못 눌러 8홀 파 선택으로 들어갔다고 하자. `par == 0`인 동안
`phase == .parSelection`이라 카운터로 갈 수 없으므로, 백버튼이 없으면 나가려면 8홀에 파를
찍어야 한다. 그 순간 8홀은 `par != 0`이 되어 전송 직전 트림 대상에서 빠지고
(`2026-08-14-watch-round-transmission-design.md` §2 결정 2), 0타짜리 빈 홀이 iOS로 넘어간다.
커밋 `4886a36`이 정확히 이 경로를 막으려고 넣은 버튼이다.

## 5. 레이아웃

```
┌──────────────────────┐
│ (‹)  7번 홀           │  헤더 30pt — 고정, ScrollView 밖
│ ┌──────────────────┐ │
│ │      Par 3       │ │
│ ├──────────────────┤ │  ScrollView — 전폭 3행, 각 46pt, 간격 6
│ │      Par 4       │ │
│ ├──────────────────┤ │
│ │      Par 5       │ │
│ └──────────────────┘ │
└──────────────────────┘
```

세로 요구량은 **헤더 30 + 스크롤 콘텐츠 150**(46×3 + 6×2)이 된다. 46mm에서는 세 행이
전부 보여 스크롤이 발생하지 않고, 40mm에서는 크라운으로 약 40pt만 굴리면 된다. 예산을
넘겨도 `ScrollView`는 잘라내지 않고 스크롤로 흡수하므로 **잘림은 구조적으로 사라진다** —
기기별 크기 세트(`ViewThatFits`)를 새로 만들 필요가 없는 이유다.

### 크라운 충돌

없다. `ScoringView`는 `TabView(.verticalPage)` 안이라 크라운 주체가 이미 있어 페이지 안에
`ScrollView`를 두지 않는다는 규칙을 세웠지만, 파 선택 화면은 가로 `TabView(.page)` 안에만
있어 세로 크라운이 비어 있다.

`.scrollBounceBehavior(.basedOnSize)`를 붙여, 콘텐츠가 다 들어가는 기기에서 헛바운스가
나지 않게 한다.

### 하단 인디케이터

가로 `TabView(.page)`의 점 인디케이터는 화면 바닥 가운데에 콘텐츠 위로 그려진다. `Par 5`
행이 가려지지 않도록 스크롤 콘텐츠 하단에 패딩 8pt를 기본값으로 두고, 시뮬레이터 실측
결과에 따라 조정한다.

### 헤더

`(‹) 7번 홀` — 원형 백버튼(`CircleIconButton`, size 30) + 홀 라벨. `CircleIconButton`은
비활성 표현을 내장하지 않으므로, 첫 홀에서는 호출부에서 `.disabled(true)` +
`.opacity(0.35)`를 붙인다 — `CountingView.ringArea`의 홀 화살표와 같은 방식이다.
라벨은 `H7`에서
`7번 홀`로 되돌린다. 공간이 남고, 카운터 화면만 영어 표기로 통일하기로 한 방침
(`2026-08-11-watch-counter-redesign-design.md`)에 따라 이 화면은 한글이다.

`CircleIconButton`이 카운터·파 선택 두 화면에서 공유되므로, CLAUDE.md의 계층 규칙에 따라
`Counting/Components/`에서 `Features/Round/Components/`로 승격한다.

## 6. 백버튼 동작

| 상태 | 아이콘 | 동작 | 비활성 조건 |
|---|---|---|---|
| 새 홀 진입 (`isEditingPar == false`) | `chevron.left` | `cancelToPreviousHole()` — phantom hole 제거 후 이전 홀 | 첫 홀 (`!canGoToPreviousHole`) |
| 재편집 (`isEditingPar == true`) | `xmark` | `cancelParEditing()` — 편집만 닫고 카운터 복귀 | 없음 (항상 활성) |

재편집에서 이전 홀로 이동하지 않는 이유: `Par` 버튼으로 들어온 사용자가 기대하는 취소는
"원래 있던 화면으로 돌아가기"이지 홀 이동이 아니다. 이전 홀로 가고 싶으면 카운터의 `‹`가
이미 그 역할을 한다. 아이콘을 `xmark`로 바꿔 두 경로가 시각적으로도 구분되게 한다.

### ViewModel 변경

```swift
/// 카운터의 [Par] 버튼으로 시작한 파 재편집을 취소하고 카운터로 돌아간다.
/// 홀은 옮기지 않으며 파 값도 그대로 둔다 — 편집 진입 자체를 무르는 것뿐이다.
func cancelParEditing() {
    isEditingPar = false
}
```

`cancelToPreviousHole()`의 재편집 분기(`guard !isEditingPar, ...` → `goToPreviousHole()`)는
호출부가 사라지지만 메서드는 그대로 둔다. 새 홀 진입 경로에서 여전히 쓰이고, 방어적
분기를 지우면 `isEditingPar`가 참인 채로 불렸을 때의 동작이 정의되지 않는다.

스냅샷은 발행하지 않는다. `isEditingPar`는 화면 분기용 UI 상태일 뿐 `RoundSnapshot`에
들어가지 않으므로, 발행할 변경이 없다. (`beginParEditing()`도 같은 이유로 발행하지 않는다.)

## 7. 검토했으나 기각한 안

**가로 3타일 배치** — `(3) (4) (5)`를 한 줄에 놓고 남는 세로를 전부 차지시키는 안. 세로
고정 요구량이 ~98pt까지 떨어져 40mm에서도 스크롤이 필요 없다는 장점이 있으나, 타일 폭이
40mm에서 약 47pt로 좁아져 전폭 행(약 154pt)보다 탭 정확도가 떨어진다. 스크롤 40pt를
지불하고 넓은 탭 타깃을 사는 쪽을 택했다.

**Select + Confirm 2단계** — 공간은 확실히 벌지만 홀당 탭이 1회 늘고, 그 대가로 얻는
오터치 방지가 이번에는 필요 없다 (§3 결정 1). `2026-07-31-golfcounter-rebuild-design.md`
§파 선택 화면의 "원탭 즉시 선택" 결정을 뒤집을 근거가 없다.

**기기별 크기 세트(`ViewThatFits`)** — `ScrollView`가 초과분을 흡수하므로 불필요하다.
`CountingView`가 크기 세트를 쓰는 이유는 링이 스크롤될 수 없는 단일 도형이기 때문이고,
파 선택은 그 제약이 없다.

## 8. 파일 변경

| 파일 | 변경 |
|---|---|
| `WatchApp/Features/Round/ParSelection/ParSelectionView.swift` | 헤더 행 + `ScrollView` 구조로 재작성 |
| `WatchApp/Features/Round/ParSelection/Components/ParBackButton.swift` | 삭제 |
| `WatchApp/Features/Round/Counting/Components/CircleIconButton.swift` | `Features/Round/Components/`로 이동 |
| `WatchApp/Features/Round/RoundViewModel.swift` | `cancelParEditing()` 추가 |

`ParOptionButton`은 변경 없다. pbxproj는 `PBXFileSystemSynchronizedRootGroup`이라 이동·삭제가
파일시스템 조작만으로 반영된다.

## 9. 테스트

View는 테스트하지 않는다(기존 방침). ViewModel만 다룬다.

- **추가**: 재편집 중 `cancelParEditing()`을 부르면 `phase`가 `.counting`으로 돌아가고,
  홀 번호·파·점수가 전부 그대로다.
- **추가**: 새 홀 진입 상태(`par == 0`)에서 `cancelParEditing()`을 불러도 파가 없으므로
  `phase`는 `.parSelection`에 머문다 — 백버튼이 이 경로에서는 `cancelToPreviousHole()`을
  부르므로 실제로는 도달하지 않지만, 메서드가 상태를 깨뜨리지 않음을 고정한다.
- **이름 변경**: `RoundViewModelHoleFlowTests.이미_점수가_있던_홀의_파_재편집_중_취소는_아무것도_제거하지_않는다`
  — 검증 내용은 그대로 둔다. §6에서 `cancelToPreviousHole()`의 재편집 분기를 남기기로
  했으므로 이 테스트는 여전히 유효하다. 다만 "취소"라는 이름이 이제는 백버튼을 가리키지
  않으므로(백버튼은 `cancelParEditing()`으로 간다), 방어적 분기를 고정하는 테스트임이
  드러나게 이름을 바꾼다.

## 10. 검증

- `make lint` · `make format`
- `xcodebuild ... -scheme "GolfCounter Watch App" ... test`
- 시뮬레이터 실측: 40mm(가장 좁음)와 46mm 두 기기에서 파 선택 화면 진입 → 세 par 버튼이
  전부 도달 가능한지, 하단 페이지 인디케이터가 `Par 5`를 가리지 않는지, 재편집 진입 후
  `xmark`가 카운터로 되돌리는지.
