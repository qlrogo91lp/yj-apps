# 하루치 핏 Phase 3 #6 — 06 공유 구현 플랜

작성일: 2026-10-06
상태: **검토 대기**

작업 브랜치(예정): `feat/haruchi-record-share`

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 기록 상세 시트 헤더 우측에 `↑` 공유 버튼을 붙인다. 누르면 YJKit `WorkoutShareButton` 메뉴(`공유…` · `스티커로 복사`)가 뜨고,
그 기록의 시간·kcal·심박이 담긴 카드가 나간다.

**Architecture:** 기록 → 카드 값 변환(제목 규칙 · `WorkoutResult` 조립)은 `Shared/Models/RecordShareBuilder` 에 순수 함수로 둔다 —
iOS 테스트 타깃이 없어 워치 테스트(`HaruchiFitWatchTests`)가 닿는 자리는 `Shared/` 뿐이다(`RecordDetailBuilder` 와 같은 이유).
워치 타깃도 `WorkoutCore` 를 링크하므로 `WorkoutResult` 까지는 `Shared/` 에서 만들 수 있다. iOS 전용인 `WorkoutShareHeader`·`WorkoutShareButton` 은
iOS 컴포넌트 `RecordShareButton` 이 조립한다.

**Tech Stack:** SwiftUI · YJKit `WorkoutShareUI` / `WorkoutCore` · Swift Testing (watchOS 테스트 타깃)

**Spec:** [제품 스펙 06절 (2026-10-06 개정)](../../../specs/shared/2026/2026-09-02-haruchi-fit-product-spec.md) ·
[아키텍처 D-M2](../../../specs/shared/2026/2026-09-02-haruchi-fit-architecture.md) ·
[로드맵 Phase 3 #6](../../../specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md) ·
[YJKit `WorkoutShareUI` 사용법](../../../../../../Packages/YJKit/README.md#workoutshareui-사용법)

## Global Constraints

- **`Packages/YJKit/` 은 수정하지 않는다** (D-M2). 카드 모양·라벨·메뉴 문구는 패키지가 소유한다
- iOS 17 최소 버전. `WatchApp/` 과 `.xcodeproj` 는 수정하지 않는다 — `WorkoutShareUI` 는 iOS 타깃에 이미 링크돼 있다
- 문구는 한국어 하드코딩. 이 앱은 String Catalog 를 쓰지 않는다
- 색은 `HaruchiPalette` 토큰만 — 로고 배경 `accent`, 로고 색은 생략(패키지가 대비를 보고 검정을 고른다)
- **ViewModel 전달은 단방향** — `RecordShareButton` 은 `RecordDetailViewModel` 을 받지 않고 값(`RecordShareContent`)만 받는다
- 소비자 책임(README) — **`WorkoutResult` 는 워크아웃 누적값**, **헤더 시각은 카드 숫자와 같은 구간**
- 테스트 저장소는 기존 `GrassFixture` 를 쓴다 (고유 이름 · `cloudKitDatabase: .none` · 컨테이너 보관)

## Review Focus

스펙이 말하지 않지만 사용자가 실제로 만날 입력·상황. 위에서부터 터질 가능성이 높은 순이다.

1. **건강 앱에서 가져온 기록** — 심박·kcal 이 nil 이다. `WorkoutResult` 는 kcal 이 `Double`(non-optional)이라 0 으로 넘기고,
   패키지가 0 과 nil 을 `–` 로 그린다 → Task 1 `missingMetricsBecomeZeroOrNil`
2. **1분이 안 되는 기록 · 구간이 0초뿐인 기록** — 제목이 `근력` 인데 상세 운동 구성은 비어 있으면 어긋난다.
   제목 판정을 운동 구성 문구와 **같은 함수**(`RecordListBuilder.segmentChips`)로 한다 → Task 1 `titleIgnoresSubMinuteKinds` · `noSegmentsTitleIsWorkout`
3. **`endedAt` 이 없는 기록(수동·구 기록)** — 카드 부제가 시작 시각만 찍히면 상세 헤더(`저녁 7:12 – 8:24`)와 다르다.
   상세 헤더와 같이 `startedAt + totalSeconds` 로 채운다 → Task 1 `missingEndUsesTotalSeconds`
4. **시트 안에서 메뉴 → 공유 시트가 또 시트로 뜬다** — 하프 시트 위에 공유 시트가 정상으로 뜨고, 닫은 뒤 상세 시트가 그대로 남는지.
   `스티커로 복사` 뒤 `복사됨` 알림이 상세 시트의 `failure` 알림과 겹치지 않는지 → Task 3 시뮬레이터 항목
5. **로고가 원 안에서 어떻게 보이는지** — `HaruchiFit.icon` 의 SVG 는 앱 아이콘용이라 원형 배지에 넣으면 여백·대비가 다를 수 있다
   → Task 2 에서 렌더된 카드 PNG 를 눈으로 본다 (결정 D3)

---

## 목표와 범위

| 스펙 06절 항목 | 이번 작업 | 비고 |
|---|---|---|
| 카드 — 패키지 소유 2×2 | ✅ | 패키지 그대로 |
| 제목 — 구간 구성으로 결정 | ✅ | 결정 D1 |
| 원형 로고 + `accent` 배지 | ✅ | 로고 에셋 추가 — 결정 D3 |
| 메뉴 — `공유…` · `스티커로 복사` | ✅ | 패키지 그대로 |
| 진입 — 상세 헤더 `↑` | ✅ | 결정 D2 |

### 검토 때 확인할 결정

플랜 승인 = 아래 결정 승인이다. 바꾸고 싶은 것이 있으면 검토 때 말한다.

- **D1. 카드 제목 = 운동 구성의 종류.** 근력만 `근력` · 유산소만 `유산소` · 둘 다 `근력 · 유산소`(처음 나온 순서) · 1분 이상인 종류가 없으면 `운동`.
  판정은 상세 운동 구성 문구와 같은 `RecordListBuilder.segmentChips` 를 쓴다 — 1분 미만 종류는 제목에도 안 나온다.
  `하루치` 같은 앱 이름은 로고가 이미 말하므로 쓰지 않는다. 부위(`가슴 · 팔`)는 넣지 않는다 — 제목 한 줄이 길어진다
- **D2. 버튼 자리 = 헤더 우측, `.standalone` 모양.** 상세는 툴바 없는 하프 시트라 `.toolbar` 를 쓸 수 없다.
  스펙 04 의 액션 줄 `공유` 는 두지 않는다 — 같은 동작을 두 곳에 두지 않는다 (스펙 04절 8번 개정과 같다)
- **D3. 로고 에셋 `HaruchiLogo` 를 iOS `Assets.xcassets` 에 새로 만든다.** `HaruchiFit.icon/Assets/haruchfit.svg` 를 복사하고
  Ralli `RalliIcon.imageset` 과 같이 `preserves-vector-representation` + 템플릿 렌더링으로 둔다(패키지가 템플릿으로 칠한다).
  SVG 가 배경을 품고 있어 템플릿으로 칠했을 때 원 전체가 메워지면, 그 자리에서 멈추고 로고 전용 SVG 를 사용자에게 받는다
- **D4. kcal 이 nil 이면 0, 심박 nil 은 그대로 nil.** `WorkoutResult` 시그니처가 그렇다. 패키지는 둘 다 `–` 로 그려 칸이 빠지지 않는다 (스펙 06절)
- **D5. 버튼은 항상 보인다.** 값이 하나도 없는 기록(수동 기록에 시간만 있는 경우)도 시간은 있으므로 카드가 성립한다.
  Ralli `SessionShareData` 처럼 nil 을 돌려 숨길 이유가 없다

### 범위 밖

- 홈 "최근 기록" · 달력에서 공유 — 각각 #7 · #8 이 상세 시트를 띄우므로 따라온다
- 워치 W2 요약에서 공유 — `WorkoutShareUI` 는 iOS 전용이다
- `편집` 버튼 — #11 (기록 상세 플랜 D1)

---

## 파일 구조

| 파일 | 작업 | 역할 |
|---|---|---|
| `Shared/Models/RecordShareContent.swift` | 새로 | 카드에 넘길 값 — `title` · `startedAt` · `endedAt` · `result: WorkoutResult` |
| `Shared/Models/RecordShareBuilder.swift` | 새로 | `WorkoutRecord` → `RecordShareContent`. 제목 규칙(D1) · 끝 시각 보정 · kcal 0 처리(D4) |
| `watchosTests/Models/RecordShareBuilderTests.swift` | 새로 | Task 1 테스트 |
| `iOSApp/Assets.xcassets/HaruchiLogo.imageset/` | 새로 | `Contents.json` + SVG (D3) |
| `iOSApp/Features/Records/Detail/Components/RecordShareButton.swift` | 새로 | 값(`RecordShareContent`)만 받아 `WorkoutShareHeader` · `WorkoutShareStyle` 를 조립해 `WorkoutShareButton` 을 그린다 |
| `iOSApp/Features/Records/Detail/RecordDetailViewModel.swift` | 수정 | `let shareContent: RecordShareContent` — init 에서 `RecordShareBuilder` 호출 |
| `iOSApp/Features/Records/Detail/RecordDetailView.swift` | 수정 | 헤더 `VStack` 을 `HStack { 날짜·시간대 ; Spacer ; RecordShareButton(content:) }` 로 |
| `docs/specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md` | 수정 (완료 시) | #6 취소선 + PR 번호 |
| 루트 `TODO.md` | 수정 (완료 시) | 하루치 #6 행 취소선, 실기기 확인 체크박스 추가 |

`Shared/` 의 새 파일은 `import WorkoutCore` 를 쓴다 — iOS·워치 두 타깃 모두 링크돼 있다.

---

## Task 1 — `RecordShareBuilder` (TDD, 워치 테스트 타깃)

- [ ] **Step 1: 실패하는 테스트 작성** — `watchosTests/Models/RecordShareBuilderTests.swift`. `GrassFixture.record(in:startedAt:totalSeconds:)` 로 기록을 만든다

| 테스트 | 입력 | 기대 |
|---|---|---|
| `strengthOnlyTitle` | 근력 30분 | `근력` |
| `mixedTitleKeepsFirstSeenOrder` | 유산소 10분 → 근력 20분 | `유산소 · 근력` |
| `titleIgnoresSubMinuteKinds` | 근력 20분 + 유산소 40초 | `근력` |
| `noSegmentsTitleIsWorkout` | 구간 없음 (건강 앱 import 의 0초 구간 포함) | `운동` |
| `resultCarriesCumulativeValues` | total 4320초 · active 300 · total 412 · 심박 128 | `durationSeconds 4320` · `caloriesBurned 300` · `totalCaloriesBurned 412` · `averageHeartRate 128` |
| `missingMetricsBecomeZeroOrNil` | kcal·심박 nil | `caloriesBurned 0` · `totalCaloriesBurned 0` · `averageHeartRate nil` |
| `missingEndUsesTotalSeconds` | `endedAt` nil · 4320초 | `endedAt == startedAt + 4320` |
| `endedAtIsKept` | `endedAt` 있음 | 그대로 |

- [ ] **Step 2: 실행해 RED 확인**

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFitWatchTests -destination "id=$WATCH" test \
  -only-testing:HaruchiFitWatchTests/RecordShareBuilderTests
```

- [ ] **Step 3: `RecordShareContent` · `RecordShareBuilder` 구현** — 끝 시각 보정은 `RecordDetailBuilder` 와 같은 식
  (`record.endedAt ?? startedAt + totalSeconds`). 두 곳에서 갈리지 않게 `WorkoutRecord` 확장의 계산 속성 하나로 뽑고 `RecordDetailBuilder` 도 그것을 쓴다
- [ ] **Step 4: GREEN + 기존 `RecordDetailBuilderTests` 통과 확인** (위 명령에서 `-only-testing` 을 빼고 전체)
- [ ] **Step 5: 커밋** — `✨ 하루치 기록을 공유 카드 값으로 바꾸는 규칙을 추가한다`

## Task 2 — 로고 에셋 `HaruchiLogo`

- [ ] **Step 1:** `iOSApp/Assets.xcassets/HaruchiLogo.imageset/` 에 `haruchfit.svg` 복사, `Contents.json` 은 `RalliIcon.imageset` 과 같은 형식
  (`preserves-vector-representation: true`, `template-rendering-intent: template`)
- [ ] **Step 2:** 템플릿으로 칠했을 때 로고 모양이 남는지 확인 — Task 3 프리뷰에서 카드를 렌더해 본다. 원이 통째로 칠해지면 **멈추고 사용자에게 로고 SVG 를 요청**한다 (D3)
- [ ] **Step 3: 커밋** — `🎨 하루치 공유 카드용 로고 에셋을 추가한다`

## Task 3 — 상세 시트에 `↑` 붙이기

- [ ] **Step 1:** `RecordShareButton` 작성 — `let content: RecordShareContent`

```swift
WorkoutShareButton(
    result: content.result,
    header: WorkoutShareHeader(title: content.title, startedAt: content.startedAt, endedAt: content.endedAt),
    style: WorkoutShareStyle(badgeColor: HaruchiPalette.accent, logo: Image("HaruchiLogo"))
)
```

- [ ] **Step 2:** `RecordDetailViewModel` 에 `let shareContent` 추가 (init 에서 `summary` 옆에)
- [ ] **Step 3:** `RecordDetailView` 헤더를 `HStack(alignment: .top)` 으로 — 왼쪽 날짜·시간대, 오른쪽 `RecordShareButton(content: viewModel.shareContent)`
- [ ] **Step 4: 빌드 · lint**

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFit -destination "id=$IOS" build
make lint && make format
```

- [ ] **Step 5: 시뮬레이터 확인**
  - 헤더 우측에 원형 `↑`, 날짜 줄과 세로 정렬이 맞는지 · `.medium` 디텐트에서 잘리지 않는지
  - 메뉴 `공유…` → 공유 시트가 상세 시트 위로 뜨고, 닫으면 상세 시트가 그대로 남는지 (Review Focus 4)
  - `사진에 저장` 으로 저장한 카드에서 제목 · 부제 시간대 · 네 칸 값이 상세 화면과 같은지, 로고가 원 안에 보이는지 (Review Focus 5)
  - kcal·심박 없는 import 기록에서 `–` 가 찍히는지
  - `스티커로 복사` → `복사됨` 알림이 뜨고 닫힌 뒤 상세 시트 조작이 되는지
- [ ] **Step 6: 커밋** — `✨ 하루치 기록 상세 헤더에서 공유 카드를 내보낸다`

## Task 4 — 문서 갱신 · PR

- [ ] 로드맵 #6 행 취소선 + PR 번호, 이 플랜 상태 갱신
- [ ] 루트 `TODO.md` — 하루치 #6 행 취소선, `집 맥북에서 할 것` 에 **공유 실기기 확인** 체크박스 추가
  (공유 시트 → 인스타 스토리 네모 카드 · 스티커 붙여넣기 · 메시지/사진 저장)
- [ ] 커밋 `📝 하루치 공유 완료를 로드맵·TODO 에 반영한다` → PR (`gh pr create`) → CI 통과 확인

## 실기기 확인 (PR 뒤, 사용자)

- 인스타 스토리에서 자기 사진 위에 `스티커로 복사` 한 카드를 붙여넣어 옮기고 키울 수 있는지
- `공유…` → 인스타 · 메시지 · 사진 저장
- 한국어 기기에서 카드 부제 시간대가 상세 헤더와 같은지
