# 하루치 핏 — 공유 카드 구성 막대 · 브랜드 제목 · 로고 여백 구현 플랜

작성일: 2026-10-20
상태: **검토 대기**

작업 브랜치: `feat/haruchi-share-composition`

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 하루치 공유 카드의 제목을 `Haruchi Fit` 으로 바꾸고, 머리줄 아래에 워치 W2 요약 화면처럼 **구성 막대 + 종류별 시간**
(`근력 26분 · 유산소 12분` / `Lift 26 min · Cardio 12 min`)을 넣는다. 원형 로고는 컴플리케이션과 같은 60% 크기로 줄인다.

**Architecture:** YJKit `WorkoutShareUI` 에 **헤더 아래 자리**(accessory)를 하나 연다. 패키지는 자리의 위치·폭·높이만 소유하고
안에 무엇을 그릴지는 모른다 — 근력/유산소는 하루치 도메인이다(루트 `CLAUDE.md` "코어는 도메인을 모른다").
자리를 넘기지 않으면 카드는 지금과 픽셀까지 같다 — **Ralli 는 호출부·결과물 모두 바뀌지 않는다.**
하루치 쪽 값 변환(구간 · 구성 문구)은 지금처럼 `Shared/Models/` 순수 함수에 두어 워치 테스트가 닿게 한다.

**Tech Stack:** SwiftUI · YJKit `WorkoutShareUI` / `WorkoutCore` · Swift Testing (YJKit 패키지 테스트 · watchOS 테스트 타깃)

**Spec:** [제품 스펙 06절 (2026-10-20 개정)](../../../specs/shared/2026/2026-09-02-haruchi-fit-product-spec.md) ·
[아키텍처 D-M2 (2026-10-20 개정)](../../../specs/shared/2026/2026-09-02-haruchi-fit-architecture.md) ·
[이전 플랜 — 06 공유](../../ios/2026/2026-10-06-record-share.md) ·
[YJKit `WorkoutShareUI` 사용법](../../../../../../Packages/YJKit/README.md#workoutshareui-사용법)

## Global Constraints

- **기존 공개 API 는 그대로 둔다.** `WorkoutShareButton(result:header:style:appearance:)` 호출이 바뀌지 않아야 한다 — Ralli `SessionShareButton` 무수정
- 자리를 넘기지 않으면 카드는 **270×200pt(1080×800px)** 그대로. 기존 `ShareCanvasTests`·`WorkoutShareRendererTests` 가 그대로 통과해야 한다
- 패키지는 **도메인 타입을 받지 않는다** — `SegmentKind` 같은 하루치 타입이 YJKit 에 들어가지 않는다
- iOS 17 최소 버전. `WatchApp/`·`.xcodeproj` 는 수정하지 않는다
- 문자열은 String Catalog 의미 키. 새 키는 만들지 않는다 — 구성 문구는 기존 `chip_kind_minutes`(`Shared` 테이블)를 쓴다
- 브랜드 표기 `Haruchi Fit` 은 번역하지 않는다 (앱 `CLAUDE.md` "문자열")
- 색은 `HaruchiPalette` 토큰만 — 근력 `accent` · 유산소 `cardio` · 문구 `dim`
- **ViewModel 전달은 단방향** — `RecordShareButton` 은 지금처럼 값(`RecordShareContent`)만 받는다

## Review Focus

스펙이 말하지 않지만 사용자가 실제로 만날 입력·상황. 위에서부터 터질 가능성이 높은 순이다.

1. **Ralli 카드가 몰래 바뀌는 것** — 카드 뷰가 제네릭이 되며 레이아웃이 한 줄이라도 달라지면 Ralli 스티커 크기가 바뀐다.
   자리 없음 = 270×200 을 테스트로 묶는다 → Task 1 `noAccessoryKeepsOriginalSize`
2. **1분 미만 구간만 있는 기록 · 0초 구간** — 막대는 그리는데 문구가 비면 어색하다. 막대를 보일지는 **문구와 같은 판정**
   (`RecordListBuilder.segmentChips` 가 비었는가)으로 정하고, 0초 구간은 막대에서도 뺀다 → Task 3 `compositionIsNilWithoutMinuteKinds` · `spansSkipZeroSeconds`
3. **구성 문구가 영어에서 길어지는 것** — `Lift 54 min · Cardio 18 min` 은 자리 폭(234pt) 안에 들어와야 한다.
   한 줄 고정 + 축소 허용, 잘리면 말줄임 → Task 4 Step 3 영어 프리뷰
4. **상세 화면과 카드의 구성이 어긋나는 것** — 같은 기록인데 상세의 막대·문구와 카드가 다르면 안 된다. 두 빌더가 **같은 함수**를 부른다 → Task 2
5. **로고 SVG 여백이 viewBox 로만 바뀌는지** — 원 안에서 마크가 가운데에 있는지, 앱 아이콘(별도 SVG)은 그대로인지 → Task 4 Step 3

---

## 목표와 범위

| 스펙 06절 (10-20 개정) 항목 | 이번 작업 | 비고 |
|---|---|---|
| 제목 `Haruchi Fit` 고정 | ✅ | Task 3 |
| 헤더 아래 구성 막대 + 종류별 시간 | ✅ | 패키지 자리 Task 1 · 값 Task 2~3 · 화면 Task 4 |
| 1분 이상 종류가 없으면 막대 없이 1080×800 | ✅ | 결정 D3 |
| 카드 크기 두 가지 고정 | ✅ | 결정 D2 |
| 로고 60% | ✅ | 결정 D4 |

### 검토 때 확인할 결정

플랜 승인 = 아래 결정 승인이다. 바꾸고 싶은 것이 있으면 검토 때 말한다.

- **D1. 패키지 API = 옵셔널 accessory 값 하나.** `WorkoutShareButton` 을 `WorkoutShareButton<Accessory: View>` 로 바꾸고
  `init(result:header:style:appearance:accessory: Accessory?)` 를 더한다. 기존 시그니처는 `where Accessory == EmptyView` 확장에 남긴다.
  `@ViewBuilder` 클로저 대신 **옵셔널 값**인 이유 — 자리 유무가 카드 크기를 바꾸므로 패키지가 `nil` 로 분명히 알아야 한다.
  클로저 안의 `if` 는 `Optional<View>` 가 되어 타입으로는 비었는지 알 수 없다. 하루치는 `content.composition.map { ShareComposition(...) }` 한 줄로 넘긴다
- **D2. 자리 높이는 패키지 상수, 카드 높이는 목표 240pt(1080×960px).** 자리는 폭 234pt(카드 270 − 좌우 패딩 18×2) · 높이 고정이고,
  넘친 내용은 잘린다(`clipped`). 막대(10) + 간격 + 문구 한 줄(11pt)이 들어갈 높이로 잡고 카드 전체를 240 에 맞춘다.
  **정확한 높이는 Task 1 Step 4 에서 렌더해 보고 확정**해 이 문서와 스펙 06절에 적는다(240 이 안 맞으면 4의 배수 px 가 되는 가장 가까운 값)
- **D3. 1분 이상 종류가 없으면 `composition = nil` → 자리 없음.** 문구와 막대를 함께 빼고 1080×800 카드다. 막대만 홀로 남기지 않는다
- **D4. 로고 여백은 SVG `viewBox` 로 준다.** `HaruchiLogo.imageset/haruchfit.svg` 의 `viewBox` 를 `0 0 815 815` → `-57 -57 929 929` 로.
  원 38pt 안 로고 프레임 26pt 에서 마크가 22.8pt(원의 60%)가 된다 — 원형 컴플리케이션 `.scaleEffect(0.6)` 과 같은 비율.
  이 에셋은 공유 카드만 쓰고(`grep "HaruchiLogo"` 1건), 앱 아이콘은 `HaruchiFit.icon` 의 원본을 따로 가져 영향이 없다.
  패키지에 로고 크기 필드를 늘리지 않는다 — 앱 하나 때문에 공용 API 를 키울 이유가 없다
- **D5. 구간·구성 문구는 `RecordDetailBuilder` 의 계산을 함수로 뽑아 두 빌더가 같이 쓴다.** 상세(04)와 카드(06)가 같은 기록에서 갈리지 않게.
  막대는 상세의 `SegmentTimelineBar` 를 그대로 재사용한다(같은 `Components/` 폴더)
- **D6. 제목에서 구성이 빠지므로 `share_title_default`(`운동`) 키를 지운다.** 다른 사용처 없음

### 범위 밖

- Ralli · 골프 카드에 자리 쓰기 — 자리는 열어만 둔다
- 카드 배경·지표 색·라벨 변경 — 패키지 소유 그대로
- 부위(`가슴 · 팔`) 표시 — 이전 플랜 D1 과 같은 이유(한 줄이 길어진다)

---

## 파일 구조

**Packages/YJKit**

| 파일 | 작업 | 역할 |
|---|---|---|
| `Sources/WorkoutShareUI/Render/ShareCanvas.swift` | 수정 | `accessorySize`(234×자리 높이) · `cardSize(hasAccessory:)`. 기존 `cardSize` 는 자리 없음 값으로 남긴다 |
| `Sources/WorkoutShareUI/Card/WorkoutShareCard.swift` | 수정 | `WorkoutShareCard<Accessory: View>` — `accessory: Accessory?` 를 헤더와 지표 사이에 고정 크기로 둔다. 프리뷰 "구성 자리" 추가 |
| `Sources/WorkoutShareUI/Render/WorkoutShareRenderer.swift` | 수정 | `image(model:style:accessory:corners:)` 제네릭. 기존 시그니처는 `EmptyView` 로 위임 |
| `Sources/WorkoutShareUI/WorkoutShareButton.swift` | 수정 | D1 — 제네릭 + 새 init, 기존 init 은 `EmptyView` 확장 |
| `Tests/WorkoutShareUITests/ShareCanvasTests.swift` | 수정 | 두 크기 · 픽셀 정수 |
| `Tests/WorkoutShareUITests/WorkoutShareRendererTests.swift` | 수정 | 자리 있음/없음 이미지 크기 |
| `README.md` | 수정 | WorkoutShareUI 사용법에 자리 예시 · 카드 크기 두 가지 |

**Apps/HaruchiFit**

| 파일 | 작업 | 역할 |
|---|---|---|
| `Shared/Models/RecordDetailBuilder.swift` | 수정 | `spans(for:)` · `compositionText(for:)` 를 static 함수로 뽑고 `summary` 가 그것을 쓴다 (D5) |
| `Shared/Models/RecordShareContent.swift` | 수정 | `composition: Composition?` 추가 — `Composition { spans: [RecordDetailSummary.Span]; text: String }` |
| `Shared/Models/RecordShareBuilder.swift` | 수정 | 제목 `Haruchi Fit` · `composition` 채우기 |
| `Shared/Shared.xcstrings` | 수정 | `share_title_default` 삭제 (D6) |
| `watchosTests/Models/RecordShareBuilderTests.swift` | 수정 | 제목 테스트 4개 → 브랜드 1개 + 구성 테스트 |
| `iOSApp/Features/Records/Detail/Components/ShareComposition.swift` | 새로 | 막대(`SegmentTimelineBar`) + 문구 한 줄. 값만 받는 순수 컴포넌트 |
| `iOSApp/Features/Records/Detail/Components/RecordShareButton.swift` | 수정 | `accessory: content.composition.map { ShareComposition(composition: $0) }` |
| `iOSApp/Assets.xcassets/HaruchiLogo.imageset/haruchfit.svg` | 수정 | `viewBox` 만 바꾼다 (D4) |

**문서**

| 파일 | 작업 | 역할 |
|---|---|---|
| `Apps/HaruchiFit/docs/specs/shared/2026/2026-09-02-haruchi-fit-product-spec.md` | 수정 (이 플랜과 함께) | 06절 2026-10-20 개정. Task 1 Step 4 뒤 카드 높이 확정값 반영 |
| `Apps/HaruchiFit/docs/specs/shared/2026/2026-09-02-haruchi-fit-architecture.md` | 수정 (이 플랜과 함께) | D-M2 "패키지를 수정하지 않는다" 개정 |
| 루트 `TODO.md` | 수정 (이 플랜과 함께 · 완료 시) | 출시 준비 표에 행 추가 → 완료 시 상태 갱신 |
| `Apps/HaruchiFit/docs/specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md` | 수정 (완료 시) | #6 비고에 이 PR |

---

## Task 1 — YJKit 헤더 아래 자리 (TDD, 패키지 테스트)

- [ ] **Step 1: 실패하는 테스트 작성**

| 파일 | 테스트 | 기대 |
|---|---|---|
| `ShareCanvasTests` | `noAccessoryKeepsOriginalSize` | `cardSize(hasAccessory: false) == 270×200` · 기존 `cardSize` 와 같다 |
| `ShareCanvasTests` | `accessoryCardIsTallerAndWholePixels` | `cardSize(hasAccessory: true).height > 200` · 너비 270 · `× scale` 이 정수 |
| `ShareCanvasTests` | `accessoryFitsInsideCardPadding` | `accessorySize.width == 270 − 36` |
| `WorkoutShareRendererTests` | `accessoryImageUsesTallerCard` | `accessory: Color.red` 를 넘긴 이미지 높이 == `cardSize(hasAccessory: true).height × 4` |
| `WorkoutShareRendererTests` | `nilAccessoryMatchesNoAccessory` | `accessory: Optional<Color>.none` 이미지 크기 == 기존 시그니처 이미지 크기 |

기존 `imageIsCardSized` 등은 그대로 둔다 — 자리 없는 경로의 회귀 테스트다.

- [ ] **Step 2: RED 확인**

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
make kit-test KIT_DESTINATION="id=$IOS"
```

- [ ] **Step 3: 구현** — `ShareCanvas` → `WorkoutShareCard` → `WorkoutShareRenderer` → `WorkoutShareButton` 순.
  카드는 `VStack(spacing: 14) { header; if let accessory { accessory.frame(ShareCanvas.accessorySize, alignment: .topLeading).clipped() }; metrics }`,
  프레임 높이는 `ShareCanvas.cardSize(hasAccessory: accessory != nil)`
- [ ] **Step 4: 자리 높이 확정** — 카드 프리뷰에 막대(10pt) + 문구(11pt 한 줄)와 같은 높이의 자리 내용을 넣어 렌더하고,
  자리 아래 지표 두 줄이 기존 카드와 같은 아래 여백을 갖는 높이를 고른다. 목표 카드 240pt. 확정값을 D2 · 스펙 06절에 적는다
- [ ] **Step 5: GREEN + Ralli 빌드**

```bash
make kit-test KIT_DESTINATION="id=$IOS"
xcodebuild -workspace YJApps.xcworkspace -scheme TennisCounter -destination "id=$IOS" build
```

- [ ] **Step 6: README** — 사용법에 자리 예시 한 단락, "카드는 1080×800" 문장을 "자리 없으면 1080×800, 있으면 1080×(확정값)" 으로
- [ ] **Step 7: 커밋** — `✨ feat: 공유 카드 헤더 아래에 앱이 채우는 자리를 연다`

## Task 2 — 구성 계산을 함수로 뽑기 (리팩터링, 워치 테스트)

- [ ] **Step 1:** `RecordDetailBuilder` 에 `static func spans(for: WorkoutRecord) -> [RecordDetailSummary.Span]`
  (`orderedSegments` 중 0초 초과) · `static func compositionText(for: WorkoutRecord) -> String?` (`segmentChips` 텍스트를 ` · ` 로, 비면 nil) 를 뽑는다.
  `summary(for:)` 는 두 함수를 부른다 — 동작 변화 없음
- [ ] **Step 2: 기존 `RecordDetailBuilderTests` 그대로 통과 확인**

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFitWatchTests -destination "id=$WATCH" test \
  -only-testing:HaruchiFitWatchTests/RecordDetailBuilderTests
```

- [ ] **Step 3: 커밋** — `♻️ refactor: 하루치 기록 구성 계산을 상세 빌더 함수로 뽑는다`

## Task 3 — 공유 값에 구성 넣기 (TDD, 워치 테스트)

- [ ] **Step 1: 테스트 교체** — `RecordShareBuilderTests` 의 제목 테스트 4개(`strengthOnlyTitle` · `mixedTitleKeepsFirstSeenOrder` ·
  `titleIgnoresSubMinuteKinds` · `noSegmentsTitleIsWorkout`)를 지우고 아래로. 스킴이 한국어 고정이라 기대값은 한국어다

| 테스트 | 입력 | 기대 |
|---|---|---|
| `titleIsBrand` | 근력 30분 | `Haruchi Fit` |
| `compositionKeepsRecordOrder` | 근력 20분 → 유산소 10분 → 근력 5분 | spans 3개 (근력 1200 · 유산소 600 · 근력 300) · 문구 `근력 25분 · 유산소 10분` |
| `compositionTextIgnoresSubMinuteKinds` | 근력 20분 + 유산소 40초 | spans 2개 (40초 포함) · 문구 `근력 20분` |
| `compositionIsNilWithoutMinuteKinds` | 유산소 40초만 | `composition == nil` |
| `spansSkipZeroSeconds` | 근력 20분 + 근력 0초 | spans 1개 |
| `compositionMatchesDetail` | 근력 20분 → 유산소 10분 | `composition.spans == RecordDetailBuilder.summary(for:).spans` · 문구도 같다 |

시간·kcal·끝 시각 테스트 4개는 그대로 둔다.

- [ ] **Step 2: RED 확인** (`-only-testing:HaruchiFitWatchTests/RecordShareBuilderTests`)
- [ ] **Step 3: 구현** — `RecordShareContent.Composition` 추가, `RecordShareBuilder` 가 `Haruchi Fit` 과
  `compositionText(for:).map { Composition(spans: spans(for:), text: $0) }` 를 채운다. `Shared.xcstrings` 에서 `share_title_default` 삭제
- [ ] **Step 4: GREEN + 워치 테스트 전체 통과**
- [ ] **Step 5: 커밋** — `✨ feat: 하루치 공유 카드 값에 브랜드 제목과 운동 구성을 담는다`

## Task 4 — 카드에 막대 붙이기 · 로고 여백 (iOS)

- [ ] **Step 1:** `ShareComposition` 작성 — `let composition: RecordShareContent.Composition`

```swift
VStack(alignment: .leading, spacing: 5) {
    SegmentTimelineBar(spans: composition.spans)
    Text(composition.text)
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(HaruchiPalette.dim)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
}
```

  프리뷰 두 개 — 한국어 `근력 54분 · 유산소 18분`, 영어 `Lift 54 min · Cardio 18 min`

- [ ] **Step 2:** `RecordShareButton` 에 `accessory: content.composition.map { ShareComposition(composition: $0) }`.
  `haruchfit.svg` `viewBox` 를 `-57 -57 929 929` 로 (D4)
- [ ] **Step 3: 카드 눈 확인** — `WorkoutShareCard` 는 패키지 internal 이라 앱에서 프리뷰할 수 없다. 시뮬레이터에서 기록 상세 → `공유…` → `사진에 저장`
  - 혼합 기록: 막대 색 순서가 상세 화면 막대와 같은지 · 문구가 상세의 운동 구성 문구와 같은지
  - 영어 기기: `Lift … · Cardio …` 가 잘리지 않는지 (Review Focus 3)
  - 1분 미만 기록: 막대 없이 기존 크기 카드 (D3)
  - 로고: 원 안 가운데 · 여백이 원형 컴플리케이션과 비슷한지 (Review Focus 5)
- [ ] **Step 4: 빌드 · lint**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFit -destination "id=$IOS" build
make lint && make format
```

- [ ] **Step 5: 커밋** — `✨ feat: 하루치 공유 카드 머리줄 아래에 운동 구성 막대를 그린다`

## Task 5 — 문서 갱신 · PR

- [ ] 이 플랜 상태 갱신, 로드맵 #6 비고에 PR 번호, 루트 `TODO.md` 행 상태 갱신
- [ ] 커밋 `📝 docs: 하루치 공유 카드 구성 막대 완료를 로드맵·TODO 에 반영한다` → PR (`gh pr create`) → CI 통과 확인. 머지는 사용자 확인 뒤

## 실기기 확인 (PR 뒤, 사용자)

- 인스타 스토리에 `스티커로 복사` 한 카드를 붙여 막대 색이 사진 위에서 구분되는지 (`cardio` 파랑이 짙은 회색 위에서)
- `공유…` → 네모 카드가 1080×960 비율로 들어가는지
- Ralli 공유 카드가 이전과 같은지 (크기 · 배치)
