# 워치 카운터 화면 재설계 (링 카운터 + 세로 페이지 인디케이터)

작성일: 2026-08-11
참조 스펙: `2026-07-31-golfcounter-rebuild-design.md` (§4 카운터 레이아웃을 개정), `2026-08-09-rallikit-adoption-and-counter-paging-design.md` (§6 페이징 방식을 개정)
영향받는 플랜: `2026-08-09-watch-rallikit-adoption-and-counter-paging.md` (구현 완료 — 이 문서가 그 결과물을 다시 고친다)

## 1. 목표

카운터 화면(가로 2/3 탭)을 두 축에서 고친다.

1. **세로 페이지 인디케이터를 만든다.** 크라운 스냅 페이징은 동작하지만 페이지가 몇 개인지·지금 어디인지 알려주는 표시가 없다. 가로 탭에는 시스템 점 인디케이터가 있는데 세로에는 없어서, 스크롤 가능하다는 사실 자체가 발견되지 않는다.
2. **카운터 레이아웃을 링 기반으로 갈아엎는다.** 현재 레이아웃은 블록이 5개(헤더·점수·＋/－·모드/Par·이전/다음)라 작은 워치에서 숨이 막히고, 조작 요소가 화면 여기저기 흩어져 있다.

## 2. 배경 — 왜 또 고치나

2026-08-09 설계로 크라운 스냅 페이징이 들어갔고 `ViewThatFits` 3단 크기 세트로 작은 워치 대응도 했다. 그런데 실기 확인 결과 두 가지가 드러났다.

**세로 페이징이 페이징처럼 안 보인다.** `ScrollView` + `.scrollTargetBehavior(.paging)`은 스냅은 하지만 인디케이터를 그려주지 않는다. 사용자는 가로 탭의 점을 보고 "가로로는 3페이지"를 알지만, 세로로도 내용이 더 있다는 걸 알 방법이 없다.

**요소를 작게 만드는 것으로는 부족했다.** 3단 크기 세트는 "같은 5블록을 어떻게든 우겨넣는" 접근이다. 40mm에서 타수 버튼이 46pt까지 줄어드는데 이는 Apple 최소 탭 타깃(44pt) 바로 위다. 문제는 크기가 아니라 **블록 개수**였다.

이번 설계는 블록을 3개(상단 정보 / 링 / 하단 조작)로 줄이고, 사라진 정보를 링의 시각 채널로 옮긴다.

## 3. 확정한 설계 결정 (brainstorming 결과)

1. **＋/－ 두 버튼을 링 하나로 합친다.** 링 안쪽 원반 탭이 스트로크 +1이다.
2. **－ 버튼을 삭제하고 취소(undo)로 대체한다.** 여러 단계 스택이며, 되돌릴 게 있는 동안 계속 떠 있다 (tennis-counter와 같은 방식).
3. **링은 파 칸수로 나뉘고 세그먼트마다 색이 다르다.** 스윙 초록 / 퍼팅 주황. 파 초과분은 바깥 링에 덧그린다.
4. **상단은 정보, 하단은 조작.** 원형 = 탭 가능이라는 규칙을 만든다.
5. **세로 페이징은 `TabView(.verticalPage)` 중첩으로 간다.** 2026-08-09 설계가 기각했던 방식이며, 그 번복 근거는 §4에 있다.
6. **스코어카드는 9홀씩 나눈다.** 페이지 안에 스크롤을 두지 않는다.
7. **퍼트 수 텍스트를 카운터 화면에서 뺀다.** 링 세그먼트 색이 대신한다.
8. **취소 버튼은 링을 절대 가리지 않는다.** 링이 이 화면의 시각적 핵심이므로, 취소는 상단 정보행 오른쪽 끝에 둔다.
9. **모드 버튼은 폭에 반응한다.** 넓으면 알약("스윙 모드"), 좁으면 원형("스윙").

## 4. 화면 구조 — 세로 페이징

### 페이지 구성

카운터가 1페이지, 스코어카드가 9홀씩 나뉘어 뒤를 잇는다.

| | 기록된 홀 1~9 | 기록된 홀 10~18 |
|---|---|---|
| 1p | 카운터 | 카운터 |
| 2p | 스코어카드 (1~9) | 스코어카드 전반 (1~9) |
| 3p | — | 스코어카드 후반 (10~18) |

페이지 수는 기록된 홀 수에서 파생한다: `1 + ceil(holeCount / 9)`. `holeCount`는 `holeScores.count`이며 `RoundViewModel`이 초기화 시점부터 항상 1 이상을 보장하므로(`holeScores = [0]`), 페이지는 최소 2개다. 10번 홀에 진입하는 순간 3페이지가 된다.

### 구현

```swift
// CounterView.swift — 세로 페이지 컨테이너 역할만 한다
TabView {
    CounterPage(viewModel: viewModel)

    ForEach(scorecardChunks, id: \.lowerBound) { range in
        Scorecard(snapshot: viewModel.snapshot, holeRange: range)
    }
}
.tabViewStyle(.verticalPage)
```

시스템이 세로 점 인디케이터를 그려준다. 가로 `TabView(.page)`의 하단 점과 세로 인디케이터가 함께 뜬다.

### 2026-08-09 결정을 번복하는 근거

2026-08-09 설계 §6은 세로 `TabView` 중첩을 명시적으로 기각했다:

> 세로 `TabView` 중첩을 택하지 않은 이유가 이것이다 — 중첩은 크라운 소유권 다툼을 만든다.

이 판단은 **스코어카드가 페이지 안에서 스크롤된다**는 전제 위에 있었다. 페이지 전환과 내부 스크롤이 둘 다 크라운을 원하면 다툼이 생기는 게 맞다.

9홀 청킹으로 그 전제가 사라진다. 페이지 안에 스크롤 뷰가 없으므로 크라운을 쓰는 주체는 페이지 전환 하나뿐이고, 다툴 상대가 없다. 기각 근거가 사라졌으므로 결정도 뒤집는다.

가로(스와이프)와 세로(크라운)가 입력 채널이 달라 충돌하지 않는다는 2026-08-09의 논리는 그대로 유효하며, 중첩 `TabView`에도 동일하게 적용된다.

### 검증해야 할 것

가로 `TabView(.page)` 안에 세로 `TabView(.verticalPage)`를 중첩했을 때 스와이프/크라운 제스처가 서로 간섭하지 않는지는 **시뮬레이터에서 확인한다.** 구현 플랜의 첫 스텝으로 넣는다.

**폴백**: 간섭이 발생하면 `ScrollView` + `.scrollTargetBehavior(.paging)`을 유지하고 `.scrollPosition(id:)`으로 현재 페이지를 추적해 세로 점을 직접 그린다. 이 경우 페이지 분할 규칙(9홀 청킹)은 그대로 쓴다 — 컴포넌트는 바뀌지 않고 `CounterView`의 컨테이너만 교체된다.

## 5. 카운터 페이지 레이아웃

```
┌────────────────────────┐
│ (Par 4) 7번 홀·41타 (↩) │  상단 — 양끝이 버튼, 가운데는 정보
│                         │
│      ╭───────────╮      │
│      │     5     │      │  링 — 파 칸수만큼 분할
│      │    +3     │      │  안쪽 원반 탭 = 스트로크 +1
│      ╰───────────╯      │
│                         │
│  ( ‹ ) [스윙 모드] ( › ) │  하단 조작행
└────────────────────────┘
```

### 상단 정보행

| 위치 | 내용 | 성격 |
|---|---|---|
| 왼쪽 | `Par 4` (원형) | **버튼** — 탭 시 `beginParEditing()` → 파 선택 화면 |
| 가운데 | `7번 홀 · 41타` | 텍스트 — 홀 번호와 라운드 누적 총 타수 (`snapshot.totalStrokes`, 현재 홀까지 포함) |
| 오른쪽 | `↩` (원형) | **버튼** — 취소 (§취소 버튼) |

**양끝이 원형 버튼, 가운데가 텍스트**인 대칭 구조다. 원형 = 탭 가능이라는 규칙이 여기서 확립되고 하단 조작행까지 이어진다. Par와 취소는 둘 다 정정용 컨트롤이라 같은 행에 묶이는 것이 의미상으로도 맞는다.

누적 타수에 `+`를 붙이지 않고 `41타`로 쓴다. 골프에서 `+`는 오버파를 뜻하는 기호이므로 `+41`은 "41 오버"로 읽힌다. 링 안의 `+3`(파 대비)과 부호가 겹쳐 서로 다른 의미가 되는 것을 피한다.

**폭 제약**: 40mm(usable 약 150pt)에서 양끝 버튼 28pt 두 개와 간격을 빼면 가운데에 약 82pt가 남는다. `7번 홀 · 41타`는 12pt 폰트로 약 90pt라 들어가지 않으므로, `tight` 세트에서는 `H7 · 41타`(약 58pt)로 축약한다. `CounterSizing`의 `usesShortHoleLabel` 플래그가 이를 결정한다.

### 링 영역

- 가운데 큰 숫자 = **현재 홀 타수**
- 그 아래 작은 글씨 = **라운드 누적 파 대비** (`+3` / `E` / `-2`)
- 탭 타깃은 **링 안쪽 원반**으로 한정한다. 링 호와 그 바깥은 탭 영역이 아니다.

`+3`을 링 안에 두고 누적 타수를 상단에 둔 이유: 큰 숫자(이 홀 타수)와 누적 타수는 같은 단위라 붙여두면 매번 범위를 구분해야 한다. 부호가 있는 `+3`은 카운트가 아님이 한눈에 읽히므로 큰 숫자 바로 아래에 와도 헷갈리지 않는다.

이 홀의 파 대비는 숫자로 쓰지 않는다 — 링 세그먼트(파 칸 + 초과 칸)가 이미 보여준다.

### 취소 버튼

**상단 정보행 오른쪽 끝**에 뜬다. 아이콘만 있는 원형이며 "취소" 텍스트는 넣지 않는다. `canUndo`가 참일 때만 나타난다.

링은 이 화면의 시각적 핵심이다. 파 칸수·스윙/퍼팅 비율·초과분을 링 하나가 전부 담당하므로, 어느 각도든 가리면 읽히는 정보가 그만큼 준다. tennis-counter의 캡슐 필(아이콘 + "취소" 텍스트, 약 73pt 폭)을 그대로 쓰면 파 4 링에서 63°가 가려지고, 40mm에서는 필 폭이 링 지름의 80%에 달해 링을 가로지르다시피 한다. 그래서 **tennis의 컴포넌트를 복사하지 않고 골프 자체 아이콘 버튼을 만든다.**

**헤더에 두는 것의 이점 세 가지:**

1. **링 주변에 제약이 전혀 없어진다.** 링은 세로 예산과 화면 폭만으로 크기가 정해지고, 취소를 피하려 지름을 줄일 이유가 사라진다.
2. **`‹` 오터치 위험이 없어진다.** 취소를 하단 왼쪽 코너에 두면 바로 아래 `‹`(이전 홀)와 인접하는데, `‹`를 잘못 누르면 홀이 바뀌면서 `strokeHistory`가 비워져 **되돌릴 기회 자체가 사라진다.** 헤더로 옮기면 이 경로가 아예 없다.
3. **헤더 높이는 이미 Par 버튼 때문에 확보되어 있다.** 취소가 세로 공간을 추가로 쓰지 않는다.

대가는 상단 오른쪽이 엄지에서 가장 먼 자리라는 것이다. 다만 취소는 오터치를 고칠 때만 쓰는 저빈도 교정 동작이므로, 접근성보다 오작동 방지와 링 크기를 우선한다.

**레이아웃 안정성**: `canUndo`가 거짓일 때 버튼이 사라져도 가운데 텍스트가 밀리면 안 된다. 헤더는 양끝 슬롯의 폭을 고정한 3열 레이아웃으로 만들고, 취소가 없을 때는 같은 크기의 투명 자리채움을 둔다. (`RoundSessionView`가 워크아웃 탭에서 이미 쓰고 있는 `Color.clear.frame(...)` 패턴과 같다.)

탭 타깃이 링 안쪽 원반으로 한정되어 있고 취소는 헤더에 있으므로, 둘은 서로 닿지 않는다. 어느 쪽을 빗맞혀도 +1이 잘못 들어가지 않는다.

### 하단 조작행

`( ‹ ) [ 모드 ] ( › )` — 좌우 화살표는 원형, 가운데 모드 버튼은 폭에 따라 모양이 바뀐다.

- `‹` → `goToPreviousHole()` (첫 홀에서는 비활성)
- `›` → `goToNextHole()`

**모드 버튼은 반응형이다.** `ViewThatFits(in: .horizontal)`로 알약 버전을 먼저 시도하고, 남는 폭에 안 들어가면 원형으로 떨어진다. `CounterView`가 이미 `ViewThatFits`를 쓰고 있으므로 새로운 패턴이 아니다.

| 변형 | 모양 | 라벨 | 조건 |
|---|---|---|---|
| wide | 알약 | `스윙 모드` / `퍼팅 모드` | 화살표 두 개를 뺀 남는 폭이 `modeWideWidth` 이상 |
| compact | 원형 | `스윙` / `퍼팅` | 그 외 |

알약 변형이 먼저 시도되도록 **고정 폭(`modeWideWidth`)을 준다.** `maxWidth: .infinity`를 주면 언제나 "들어간다"고 판정되어 `ViewThatFits`가 항상 알약을 고르므로, 좁은 화면에서 라벨이 잘린다.

글자·테두리 색이 링 세그먼트 색(초록/주황)과 같다. 색이 "모드"라는 단어 역할을 대신하므로 — 지금 이 색이 링에 들어간다는 뜻 — compact 변형이 두 글자로 줄어도 의미가 유지된다. 이것이 단일 토글 버튼의 고질적 모호함("현재 상태인가 누르면 갈 곳인가")을 해소한다.

하단 중앙은 엄지가 가장 닿기 쉬운 자리다. 홀 이동을 상단 구석에 두는 것보다 조작이 편하다.

## 6. 링 렌더링 규칙

### 세그먼트 구성

- **슬롯 수 = 현재 홀의 파** (3/4/5). 파 선택 화면이 파를 강제하므로 카운터 화면에서 파가 0인 경우는 없다.
- 12시부터 시계방향으로 1타에 한 칸씩 채운다.
- **색**: 스윙 초록, 퍼팅 주황. 아직 안 친 칸은 어두운 회색.
- **채우는 순서는 스윙 먼저, 퍼팅 나중**으로 고정한다.

### 파 초과 처리

파를 넘으면 주 링 바깥에 얇은 링을 추가로 그리고 초과 타수만큼 채운다. 바깥 링도 같은 슬롯 단위(파 칸수)로 나눈다.

초과가 한 바퀴를 또 넘으면(파 3에 10타 같은 극단) **바깥 링은 꽉 찬 상태로 멈춘다.** 정확한 값은 가운데 숫자가 담당한다. 링을 여러 겹으로 늘리지 않는다.

파 이내일 때는 바깥 링을 아예 그리지 않는다.

### 알려진 한계 — 입력 순서를 저장하지 않는다

모델은 `holeScores`(총 타수)와 `puttCounts`(퍼트 수)만 저장하고 입력 순서를 저장하지 않는다. 따라서 링은 항상 스윙을 먼저 그린다.

퍼팅 모드로 한 타를 넣은 뒤 다시 스윙 모드로 넣으면, 주황 칸이 한 칸 뒤로 밀려나며 눈에 보이게 움직인다. 실제 골프는 스윙 후 퍼팅 순서라 이 상황이 거의 생기지 않으므로 **감수하고 넘어간다.**

순서를 저장하려면 `RoundSnapshot`(컴플리케이션과 공유되며 App Group에 직렬화됨)까지 바뀌어야 한다. 시각적 미세 이슈 하나를 위해 지불할 비용이 아니다. 나중에 필요해지면 additive로 필드를 추가하면 되므로 되돌릴 수 있는 결정이다.

### 세그먼트 계산은 순수 타입으로 분리

링 세그먼트 계산은 뷰가 아니라 로직이므로 `RingSegments`라는 순수 타입으로 분리해 테스트한다. UI 프레임워크를 import하지 않으며, 색은 SwiftUI `Color`가 아니라 자체 enum으로 표현한다.

```swift
struct RingSegments {
    enum Kind { case swing, putt, empty }

    let slots: [Kind]       // 주 링 — 길이 = par
    let overflow: [Kind]    // 바깥 링 — 비어 있으면 안 그림

    init(par: Int, strokes: Int, putts: Int)
}
```

## 7. 취소(undo) 모델

### 구조

`RoundViewModel`에 입력한 타의 **종류 기록**만 쌓는다. 상태 전체 스냅샷이 아니다.

```swift
private var strokeHistory: [StrokeInputMode]   // 현재 홀에서 친 타의 종류 순서
var canUndo: Bool { !strokeHistory.isEmpty }
```

- `incrementStroke()` → `strokeHistory.append(inputMode)`
- `undo()` → pop. 타수 −1, pop한 것이 `.putt`이면 퍼트도 −1. 정확한 역연산이다. 마지막에 `publishSnapshot()`을 호출해 컴플리케이션·App Group 상태를 갱신한다 — 상태를 바꾸는 모든 경로가 스냅샷을 발행한다는 기존 규칙을 따른다.
- `decrementStroke()` **삭제**

종류만 저장하면 충분한 이유: `incrementStroke()`가 하는 일이 모드에 따라 (타수 +1) 또는 (타수 +1, 퍼트 +1) 두 가지뿐이므로, 어느 쪽이었는지만 알면 되돌릴 수 있다. 배열 전체를 복사할 필요가 없다.

### 스코프 — 현재 홀로 한정

홀을 옮기면(`goToNextHole()` / `goToPreviousHole()` / `cancelToPreviousHole()`) `strokeHistory`를 비운다. `resetHoleLocalState()`가 그 자리다.

근거: 홀을 넘긴 뒤 취소를 눌렀는데 화면이 이전 홀로 통째로 돌아가면 사용자가 예측할 수 없다. "지금 보고 있는 홀의 마지막 입력을 되돌린다"가 유일하게 예측 가능한 의미다.

실수로 다음 홀에 진입한 경우는 파 선택 화면의 `cancelToPreviousHole()`(phantom hole 제거)이 이미 담당하고 있으므로, 취소가 그 역할까지 떠맡을 필요가 없다.

### 크래시 복구 시

`init(resuming:)`으로 복구하면 `strokeHistory`가 비어 있어 취소 버튼이 뜨지 않는다. 되돌릴 대상을 모르는 상태에서 뭔가를 되돌리는 것보다 안전하다. 사용자가 새 타를 입력하는 순간부터 다시 뜬다.

### 파 재선택은 스택에 넣지 않는다

`selectPar()`는 `strokeHistory`를 건드리지 않는다. 파는 Par 버튼으로 언제든 다시 고칠 수 있어 취소가 필요 없고, 파를 바꿔도 이미 친 타는 유효하므로 스택을 비울 이유도 없다.

## 8. 애니메이션과 햅틱

### 링 채움

각 슬롯을 `Circle().trim(from:to:)`로 그리고, 새로 채워지는 칸의 끝값을 애니메이션한다. `Shape.trim`은 애니메이터블이라 호가 그려지듯 차오른다.

- **지속시간 0.2초 이하.** 골프는 한 홀에 연속으로 여러 번 누를 수 있어, 길면 다음 탭에서 애니메이션이 겹쳐 밀린다.
- `.animation(_:value:)`로 값 기반으로 건다. 진행 중 새 값이 들어오면 그쪽으로 바로 따라간다.
- `@Environment(\.isLuminanceReduced)`가 `true`면(Always-On, 손목 내림) 애니메이션을 끈다.

### 숫자

가운데 큰 숫자는 기존 `.contentTransition(.numericText())`을 유지한다. 링과 숫자가 함께 움직여 입력 피드백이 확실해진다.

### 취소 버튼 등장/퇴장

`.transition(.scale.combined(with: .opacity))`. 모양은 tennis-counter와 다르지만(§5) 등장·퇴장 트랜지션은 같은 것을 쓴다 — 두 앱의 취소가 같은 감각으로 나타나고 사라진다.

### 햅틱

| 동작 | 패턴 |
|---|---|
| 스트로크 입력 | `.click` (기존 유지) |
| 취소 | `.directionDown` (기존 − 버튼이 쓰던 것) |

## 9. 파일 변경

### 신규

| 파일 | 역할 |
|---|---|
| `WatchApp/Features/Round/Counter/Components/StrokeRing.swift` | 링 그리기 (`RingSegments`를 받아 렌더) |
| `WatchApp/Features/Round/Counter/Components/RingSegments.swift` | 세그먼트 계산 — 순수 타입, UI 프레임워크 미import |
| `WatchApp/Features/Round/Counter/Components/CounterHeader.swift` | 상단 정보행 (Par 버튼 · 홀번호+누적타수 · 취소 버튼). 취소가 없을 때도 가운데가 안 밀리도록 양끝 슬롯 폭을 고정 |
| `WatchApp/Features/Round/Counter/Components/CounterControls.swift` | 하단 조작행 (‹ · 모드 · ›) |
| `WatchApp/Features/Round/Counter/Components/ModeButton.swift` | 모드 버튼 — `ViewThatFits`로 알약/원형 전환 |
| `WatchApp/Features/Round/Counter/Components/UndoButton.swift` | 원형 아이콘 취소 버튼 (골프 자체 구현 — tennis 복사 아님, §5 참조) |

### 재작성

| 파일 | 변경 |
|---|---|
| `Counter/CounterView.swift` | 세로 `TabView(.verticalPage)` 컨테이너. `ViewThatFits` 3단 호출은 `CounterPage` 안으로 이동 |
| `Counter/Components/CounterPage.swift` | 3블록 레이아웃(헤더 / 링+취소 / 조작행)으로 전면 재작성 |
| `Counter/Components/CounterSizing.swift` | 새 요소 기준으로 필드 교체 (§10) |
| `Counter/Components/Scorecard.swift` | `holeRange: Range<Int>` 파라미터 추가. 합계 줄은 **마지막 청크에만** 표시하고 라운드 전체 합계를 쓴다 |
| `Round/RoundViewModel.swift` | `strokeHistory` · `canUndo` · `undo()` 추가, `decrementStroke()` 삭제, `resetHoleLocalState()`에서 히스토리 클리어 |

### 삭제

| 파일 | 사유 |
|---|---|
| `Counter/Components/StrokeButton.swift` | 링 안쪽 원반 탭이 대체 |
| `Counter/Components/HoleNavigation.swift` | `CounterControls`로 흡수 |
| `Counter/Components/ModeToggle.swift` | `ModeButton`으로 대체 |

`Shared/`는 손대지 않는다 — `RoundSnapshot`·`GolfRound`·서비스 전부 그대로다. `ParSelectionView`도 변경 없다. 파가 0이면 자동으로 파 선택 화면이 뜨는 현재 동작이 그대로 유지된다.

pbxproj는 `PBXFileSystemSynchronizedRootGroup`이므로 파일 생성·삭제가 빌드에 자동 반영된다.

## 10. CounterSizing 재구성

기존 필드(`strokeButton`, `strokeIcon`, `navHeight`)는 사라진 요소의 것이므로 전부 교체한다. `ViewThatFits`가 regular → compact → tight 순으로 시도하는 구조는 유지하며, **기기 모델을 분기하지 않는다.**

| 필드 | regular | compact | tight |
|---|---|---|---|
| `headerHeight` | 36 | 32 | 28 |
| `headerFont` | 14 | 13 | 12 |
| `ringDiameter` | 103 | 84 | 70 |
| `ringStroke` | 11 | 10 | 8 |
| `overflowStroke` | 5 | 4.5 | 4 |
| `overflowGap` | 4 | 3.5 | 3 |
| `scoreFont` | 40 | 33 | 28 |
| `relativeFont` | 13 | 12 | 11 |
| `parButtonSize` | 36 | 32 | 28 |
| `undoSize` | 36 | 32 | 28 |
| `arrowSize` | 40 | 36 | 32 |
| `modeHeight` | 48 | 44 | 38 |
| `modeWideWidth` | 100 | 92 | 84 |
| `usesShortHoleLabel` | false | false | true |
| `spacing` | 6 | 5 | 4 |

세로 합계 = `headerHeight + spacing + outerRadius*2 + spacing + modeHeight` → regular 228pt / compact 196pt / tight 166pt.

**`ringDiameter`가 아니라 `outerRadius*2`가 실제 렌더 값이다** — `StrokeRing`은 초과 링이 비어 있어도 그 공간을 항상 프레임에 예약하기 때문이다(구현 중 발견, 최종 리뷰에서 수정). `ringDiameter`는 위 표의 값이 아니라 `outerRadius*2`가 예산 안에 들어오도록 역산한 값이다.

취소와 Par가 둘 다 헤더 안에 들어가므로 **세로 예산에서 이 둘의 몫은 `headerHeight` 하나뿐이다.** 그래서 `parButtonSize`와 `undoSize`는 `headerHeight`와 같은 값으로 묶는다.

### 링 크기를 정하는 제약

링은 두 방향 모두에서 잘리지 않아야 한다. 바깥 초과 링까지 포함한 실제 반지름은 다음과 같다:

```
outerRadius = ringDiameter/2 + ringStroke/2 + overflowGap + overflowStroke
```

- **세로**: 위 합계가 화면 안전 영역 높이 이내여야 한다.
- **가로**: `2 × outerRadius`가 화면 폭에서 좌우 패딩을 뺀 값 이내여야 한다.

취소를 헤더로 올린 덕에 링 주변에 다른 제약이 없다 — 위 두 개만 만족하면 된다.

### 헤더 축약

`usesShortHoleLabel`이 참이면 가운데 텍스트를 `7번 홀 · 41타` 대신 `H7 · 41타`로 쓴다. 40mm에서 양끝 원형 버튼을 뺀 가운데 폭이 약 82pt인데 전체 표기는 약 90pt라 넘치기 때문이다.

**이 값들은 출발점이며 구현 중 실측으로 조정한다.** 확인할 것: 40mm에서 위 두 제약이 성립하는지, `usesShortHoleLabel`이 참일 때 텍스트가 실제로 들어가는지, `modeWideWidth`가 안 들어가 compact 변형으로 떨어지는지.

## 11. 테스트

`watchosTests/Round/` 아래, 소스 구조를 미러링한다. View는 규칙대로 테스트하지 않는다.

### 신규

**`RoundViewModelUndoTests.swift`**

- 스윙 모드로 입력 후 `undo()` → 타수 −1, 퍼트 불변
- 퍼팅 모드로 입력 후 `undo()` → 타수 −1, 퍼트 −1
- 여러 번 입력 후 연속 `undo()` → 역순으로 정확히 되돌아감
- 빈 스택에서 `undo()` → 상태 불변, 크래시 없음
- `goToNextHole()` 후 `canUndo == false`
- `goToPreviousHole()` 후 `canUndo == false`
- `init(resuming:)` 직후 `canUndo == false`
- `selectPar()`는 `canUndo`를 바꾸지 않음
- `undo()` 후 스냅샷이 재발행됨 (`RoundSnapshotPublisherSpy`로 확인)

**`RingSegmentsTests.swift`**

- 0타 → 전 슬롯 `.empty`, `overflow` 비어 있음
- 파 이내 (파 4, 3타 스윙 3) → 초록 3 + `.empty` 1
- 정확히 파 (파 4, 4타) → 전 슬롯 채움, `overflow` 비어 있음
- 초과 (파 4, 5타 중 퍼트 2) → 초록 3 + 주황 1, `overflow`에 주황 1
- 초과가 한 바퀴를 넘음 (파 3, 10타) → `overflow`가 파 칸수에서 멈춤
- 퍼트가 타수보다 많은 불가능한 입력이 들어와도 인덱스를 벗어나지 않음

### 갱신

- `RoundViewModelTests.swift` — `decrementStroke` 관련 케이스 삭제
- `CounterSizingTests.swift` — 새 필드 기준으로 재작성

## 12. 기존 스펙 개정 사항

이 문서가 확정되면 아래를 반영한다.

| 문서 | 개정 내용 |
|---|---|
| `2026-07-31-golfcounter-rebuild-design.md` §4 | "페이지 2/3 메인 카운터" ASCII 다이어그램과 설명을 링 레이아웃으로 교체. 세로 페이징을 `TabView(.verticalPage)` + 9홀 청킹으로 갱신 |
| `2026-08-09-...-design.md` §6 | 세로 `TabView` 중첩 기각 결정을 번복했음과 그 근거(§4)를 명시. `CounterSizing` 표를 §10으로 대체 |
| `CLAUDE.md` | 변경 없음 — 폴더 구조·컨벤션에 영향 없음 |

## 13. 범위 밖

- **홀 수 선택(9홀/18홀) 화면** — 2026-07-31 스펙 §4에 있으나 미구현이며 플랜 ④ 범위다. 이 설계는 홀 수를 상한으로 쓰지 않고 `holeScores.count`(기록된 홀 수)에서 페이지 수를 파생하므로, 홀 수 선택이 나중에 들어와도 충돌하지 않는다.
- **종료 요약 화면과 iOS 전송** — 플랜 ④ 범위. `RoundViewModel.finish()`는 지금처럼 스냅샷만 지운다.
- **로컬라이즈** — 신규 문자열("스윙", "퍼팅", "타", "번 홀")은 이번에도 한국어 하드코딩으로 둔다. 플랜 ⑦에서 String Catalog로 일괄 처리한다.
- **iOS 앱과 컴플리케이션** — 손대지 않는다.
