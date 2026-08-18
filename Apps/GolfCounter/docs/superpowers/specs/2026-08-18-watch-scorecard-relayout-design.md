# 워치 스코어카드 재배치 + 정수 포맷 지정자 크래시 수정 설계

작성일: 2026-08-18
참조 스펙: `2026-07-31-golfcounter-rebuild-design.md` §4, `2026-08-11-watch-counter-redesign-design.md`(스코어카드 페이지 구조), `2026-08-17-localization-design.md`(`scorecard_row`/`scorecard_total` 키 — 이 문서가 두 키를 폐기한다)
계기: TestFlight 실기기에서 스코어 화면을 위로 스와이프해 스코어카드 페이지(합계 줄)에 진입하면 크래시로 홈 화면에 튕기는 문제 (2026-08-18 보고)

## 1. 근본 원인 — `%lld`와 arm64_32

워치 실기기(arm64_32, ILP32)에서 Swift `Int`는 32비트다. 그런데 워치·컴플리케이션·iOS의 `.strings`가 정수 보간에 전부 `%lld`(64비트 `long long`)를 쓰고 있었다. 32비트 값을 64비트로 읽으면 상위 32비트에 스택 값이 섞여 숫자가 깨지고, 뒤따르는 `%@` 인자까지 밀려 유효하지 않은 포인터를 객체로 해석해 크래시로 이어진다.

시뮬레이터(arm64, 64비트)에서는 두 크기가 우연히 같아 재현되지 않는다 — 이번 버그가 실기기에서만 나타난 이유다.

**수정**: 정수 보간에 쓰는 모든 지정자를 `%ld`(`long`)로 통일한다. `long`은 arm64_32·arm64 양쪽에서 항상 Swift `Int`와 같은 크기다. 워치·컴플리케이션뿐 아니라 iOS도 (안전상 문제는 없지만) 일관성을 위해 함께 통일한다.

**회귀 방지**: `watchosTests/Localization/FormatSpecifierWidthTests.swift`가 세 타깃의 `.strings` 파일을 `#filePath` 기준 절대 경로로 직접 읽어 `%lld`·`%d` 등 안전하지 않은 정수 지정자가 없는지 검사한다. `Bundle` 조회가 아니라 파일을 직접 읽는 이유: 시뮬레이터에서 문자열을 실제로 포맷해서는 이 버그가 재현되지 않으므로, 타깃과 무관하게 `.strings` 내용 자체를 정적으로 검사해야 한다.

## 2. 스코어카드 재배치

크래시 원인이 하필 합계 줄(`scorecard_total`, `%lld`·`%lld`·`%@` 세 지정자)이었던 김에, 스코어카드 레이아웃 자체도 다시 설계했다.

### 2.1 문제였던 것

- **9홀이 실기기에서 다 안 들어갔다.** 행 15pt·간격 3pt 기준 9행 = 159pt, 합계 줄까지 있으면 181pt. 40mm 세로 예산(138.5pt)을 20~43pt 초과했고, `TabView(.verticalPage)` 페이지 안에는 `ScrollView`를 못 쓰므로(크라운 소유권 다툼, `2026-08-11` 문서 참조) 넘친 내용은 그냥 잘려서 안 보였다.
- **합계가 페이지마다 옮겨 다녔다.** `showsTotal`이 "지금까지 진행한 홀 수와 청크 끝이 같은가"로 정해져, 라운드가 진행될수록(예: 4홀→10홀 진입) 합계가 실리는 페이지가 계속 바뀌었다.

### 2.2 결정된 디자인

- **9홀 청킹은 유지한다** — `ScorecardChunks.holesPerPage = 9`는 그대로. 18홀 라운드는 스코어카드 2페이지.
- **헤더로 합계를 페이지마다 고정한다.** `ScorecardHeader`가 라운드 전체 합계(`총타수` + `오버파`, 예: `44 +8`)를 모든 스코어카드 페이지 상단에 표시한다. 마지막 청크에만 붙던 합계 줄은 삭제했다. 단위·구분 기호 없이 숫자 두 개만 — 한국어·영어 표기를 통일했다(기존에는 한국어만 "타" 단위가 붙었다).
- **Par 열과 홀별 퍼트를 뺐다.** Par는 `타수 − 오버파`로 유도되는 중복 정보였다. 퍼트는 요약 화면·iOS 기록에서 계속 볼 수 있다.
- **2열 × 5행 격자 + 격자선.** 홀 번호는 원형 배지(왼쪽), 타수(굵게)·오버파(회색, 고정폭 오른쪽 정렬)는 오른쪽에 모은다. 열 사이 세로선, 행 사이 가로선(마지막 행 제외). 9홀은 홀수라 마지막 행은 왼쪽 칸만 채운다.
- **`CountingSizing`과 같은 패턴으로 3단 크기 세트**(`ScorecardSizing.regular/compact/tight`)를 두고 `ViewThatFits(in: .vertical)`로 기기에 맞는 세트를 고른다 — 여유 공간을 그냥 버리지 않고 큰 화면에서는 글자를 더 키운다.

| | regular (Ultra·46mm) | compact (44mm·45mm) | tight (40mm·41mm) |
|---|---|---|---|
| 타수 폰트 | 15pt | 14pt | 13pt |
| 배지 지름 | 19pt | 17pt | 15pt |
| 헤더 폰트 | 17pt | 16pt | 15pt |
| 세로 소요 / 예산 | 156 / 167.5 | 147 / 152 | 129 / 138.5 |

색은 카운터 링 중앙(`ScoreRing`)과 같은 위계를 그대로 따른다 — 타수는 기본색, 오버파는 `.secondary`. 이 앱의 "색은 링·모드 버튼만 갖는다"는 원칙(`CircleIconButton` 주석)을 스코어카드에도 지켜, 새 색을 추가하지 않았다.

### 2.3 이븐파 표기 — `E` → `0`

`ScoreFormat.relativeToPar`·`averageRelativeToPar`가 이븐파를 골프 관례 표기 `E`(`0.0`대신 `E`) 대신 `0`(`averageRelativeToPar`는 `0.0`)으로 바꿨다. 스코어카드뿐 아니라 카운터 링·요약 화면·컴플리케이션·iOS 기록·통계 전체에 적용되는 전역 변경이다.

## 3. 변경 파일

| 파일 | 변경 |
|---|---|
| `WatchApp/ko·en.lproj/Localizable.strings` | 정수 지정자 `%ld` 통일, `scorecard_row`·`scorecard_total` 삭제 |
| `ComplicationApp/ko·en.lproj/Localizable.strings` | `complication_strokes` → `%ld` |
| `iOSApp/ko·en.lproj/Localizable.strings` | 정수 지정자 `%ld` 통일 |
| `watchosTests/Localization/FormatSpecifierWidthTests.swift` | 신규 — 회귀 방지 |
| `WatchApp/Features/Round/Scorecard/ScorecardSizing.swift` | 신규 — 3단 크기 세트 |
| `WatchApp/Features/Round/Scorecard/Components/ScorecardHeader.swift` | 신규 |
| `WatchApp/Features/Round/Scorecard/Components/HoleBadge.swift` | 신규 |
| `WatchApp/Features/Round/Scorecard/ScorecardView.swift` | 2열 격자로 재작성, `showsTotal` 제거 |
| `WatchApp/Features/Round/ScoringView.swift` | 스코어카드 페이지에 `ViewThatFits(in: .vertical)` 적용 |
| `Shared/Models/ScoreFormat.swift` | `E` → `0`/`0.0` |
| `watchosTests/Shared/ScoreFormatTests.swift`, `ComplicationStateTests.swift`, `iosTests/Shared/ScoreFormatAverageTests.swift` | `E` 기대값 수정 |
| `WatchApp/Features/Round/ParSelection/ParSelectionView.swift` | 백버튼 30→36pt(카운터 홀 이동 버튼과 통일), 헤더-Par 간격 6→12pt |

## 4. 검증

- `xcodebuild test`로 워치·iOS 유닛 테스트 전체 통과 확인 (시뮬레이터는 arm64라 §1의 크래시 자체는 재현되지 않는다 — `FormatSpecifierWidthTests`가 정적 검사로 대신한다).
- 실기기 검증은 사용자가 직접 진행 — 홈 화면 숫자·스코어카드 합계·페이지 전환에서 크래시 없는지 확인.
