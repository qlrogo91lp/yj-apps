# 하루치 핏 Phase 3 #5 — 04 기록 상세 구현 플랜

작성일: 2026-10-06
상태: **작성 완료 — 사용자 검토 전** · 2026-10-06 main 갱신(PR #37·#38·#39) 반영 — ViewModel 전달 규칙, 테스트 저장소 격리, `origin/main` 기준 출발

현재 위치: `/Users/yj/Workspace/Projects/yj-apps-worktrees/haruchi-record-detail` · 브랜치 `feat/haruchi-record-detail`.
플랜은 이 워크트리의 미커밋 파일이다. 메인 체크아웃에는 아직 없으며, Task 0의 워크트리 생성·문서 이동은 이미 끝났다.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 기록 탭의 행을 탭하면 기록 상세 하프 시트가 열리고, 거기서 부위(멀티)·메모를 고치면 즉시 저장되며, 목록 행에도 부위가 보이게 한다.

**Architecture:** `WorkoutRecord` 에 부위 필드(`bodyPartsRaw`)를 더하고, 편집 규칙(토글·메모 정규화·재전송 시 이어받기)은
`Shared/Persistence/WorkoutRecord+Annotations.swift` 에, 표시 규칙(헤더·요약 3칸·운동 구성)은 `Shared/Models/RecordDetailBuilder` 에
순수 함수로 둔다 — iOS 테스트 타깃이 없어 워치 테스트(`HaruchiFitWatchTests`)가 `@testable import` 로 닿는 자리는 `Shared/` 뿐이다
(`RecordListBuilder` 와 같은 이유). iOS 쪽 `RecordDetailViewModel` 은 그 둘을 부르고 `save()` 하는 배선만 맡는다.

**Tech Stack:** SwiftUI (iOS 17 `presentationDetents`) · SwiftData · Swift Testing (watchOS 테스트 타깃)

**Spec:** [제품 스펙 04절 · D1 · D6](../../../specs/shared/2026/2026-09-02-haruchi-fit-product-spec.md) ·
[아키텍처 3절 데이터 모델](../../../specs/shared/2026/2026-09-02-haruchi-fit-architecture.md) ·
[로드맵 Phase 3 #5](../../../specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md)

## Global Constraints

- iOS 17 / watchOS 10 최소 버전. 새 API는 이 범위 안에서만 쓴다
- 부위는 **6개 고정** — 가슴 · 등 · 어깨 · 팔 · 하체 · 코어. 유산소는 넣지 않는다 (D1)
- 부위는 **멀티 선택, 탭 = 토글, 저장 자동** (D1). 저장 버튼을 두지 않는다
- 부위 섹션은 **유산소 전용 세션에서도 항상 표시**하고, 태깅을 유도하는 CTA 를 두지 않는다 (스펙 04)
- 메모는 부위와 독립 (D6). 비어 있으면 플레이스홀더 `메모 추가하기…`
- 전환 횟수를 표시하지 않는다 (D7). 운동 구성은 바와 종류별 합계로만
- 기록 탭에는 집계도 차트도 없다 (스펙 03b). 운동 구성 바는 차트가 아니라 한 기록의 구성 표시다
- 색은 `HaruchiPalette` 토큰만 쓴다 — 근력 `accent`, 유산소 `cardio`, 심박 `hr`
- 문구는 한국어 하드코딩. 이 앱은 String Catalog 를 쓰지 않는다
- HealthKit 메타데이터에 부위를 넣지 않는다 (아키텍처 3절). iOS 앱은 **HealthKit 읽기 전용**을 유지한다
- SwiftData 새 속성은 CloudKit 제약대로 **기본값을 갖는다** (`.unique` 금지 · optional 또는 기본값)
- **ViewModel 전달은 단방향** (루트 `CLAUDE.md` "ViewModel 전달", PR #37) — 컴포넌트는 VM 을 받지 않고 값과 콜백만 받는다.
  시트는 자기 VM 을 소유하고 밖에는 값(`record`)과 콜백(`onDelete`)만 드러낸다. 콜백을 `RecordsViewModel` 메서드에 잇는 일은 `RecordsView` 가 한다
- 테스트 저장소는 **테스트마다 고유 이름 · `cloudKitDatabase: .none` · 컨테이너 보관** (Ralli PR #38 `TestPersistence` 처방). Task 1 Step 0 이 `GrassFixture` 를 그렇게 바꾼다
- `Packages/YJKit/`, `WatchApp/`, `.xcodeproj` 는 수정하지 않는다

## Review Focus

스펙이 말하지 않지만 사용자가 실제로 만날 입력·상황. 위에서부터 터질 가능성이 높은 순이다.

1. **태깅한 기록을 워치가 다시 보낸다** (`transferUserInfo` 재배달) — `iOSApp.save(_:)` 의 `upsert(replacing:)` 는 **지우고 새로 넣으므로**
   부위·메모가 사라진다. 사용자는 붙인 태그가 남아 있기를 기대한다 → Task 1 `adoptAnnotationsSurvivesReplacement` 테스트 + `save(_:)` 수정
2. **시트에서 부위를 바꾸고 닫는다** — `RecordsView` 의 `onChange(of: records)` 는 모델 **동일성**으로 비교해 속성 변경에 안 걸린다.
   목록 행의 부위 줄이 그대로면 저장이 안 된 것처럼 보인다 → Task 4 `finishDetail()` 이 시트가 닫힐 때 다시 만든다 (View 라 Task 4 Step 8 시뮬레이터 항목으로 확인)
3. **시트에서 삭제한다** — 떠 있는 시트가 지워진 모델을 읽으면 크래시한다 → Task 4 는 시트가 **완전히 내려간 뒤**(`onDismiss`) 지운다 (시뮬레이터 항목)
4. **메모를 쓰다가 `완료` 없이 시트를 쓸어내린다 · 공백만 남긴다** — 쓴 내용이 남고, 공백뿐이면 메모가 없는 것으로 → Task 1 `memoIsTrimmedAndEmptyBecomesNil` + Task 4 `onDisappear` 커밋 (시뮬레이터 항목)
5. **건강 앱에서 가져온 기록** — 심박·kcal 이 없거나, 구간이 0초거나, 1분이 안 되는 기록. 요약 3칸이 무너지지 않고 `0분` 같은 거짓 숫자가 없어야 한다
   → Task 2 `missingMetricsKeepTheirPlace` · `subMinuteRecordSaysUnderOneMinute` · `emptyCompositionHasNoBar`

---

## 목표와 범위

스펙 04절의 8개 구성 중 6개를 이번에 하고, 로드맵 #5 비고대로 **목록 행의 부위 표시와 탭 진입**까지 붙인다.

| 스펙 항목 | 이번 작업 | 비고 |
|---|---|---|
| 1 그랩 핸들 | ✅ | `presentationDragIndicator(.visible)` |
| 2 헤더 — 날짜 / 시간대 범위 | ✅ | 우측 `↑` 공유는 ❌ — 결정 D2 |
| 3 요약 3칸 — 총 시간 / kcal / 평균 심박 | ✅ | 값 없으면 `–` — 결정 D3 |
| 4 운동 구성 — 타임라인 바 + `근력 54분 · 유산소 18분` | ✅ | |
| 5 구분선 | ✅ | |
| 6 부위 — 칩 6개, 탭 = 토글, 저장 자동 | ✅ | |
| 7 메모 — 플레이스홀더 | ✅ | 저장 시점은 결정 D6 |
| 8 액션 `삭제` / `편집` / `공유` | `삭제` 만 | `편집` 은 결정 D1, `공유` 는 D2 |
| (로드맵) 목록 행 부위 칩 · 행 탭 → 시트 | ✅ | 부위는 칩 대신 한 줄 텍스트 — 결정 D5 |

### 검토 때 확인할 결정

플랜 승인 = 아래 결정 승인이다. 바꾸고 싶은 것이 있으면 검토 때 말한다.

- **D1. `편집` 버튼을 이번에 두지 않는다.** 스펙이 무엇을 편집하는지 정하지 않았다. 부위·메모는 시트 안에서 바로 고치므로
  남는 후보는 시각·시간·유형인데, 그건 **#11 수동 기록 폼**과 같은 입력이다. #11 플랜을 쓸 때 폼을 재사용하는 편집으로 정한다.
  작동하지 않는 버튼을 미리 노출하지 않는다 (탭 셸·목록 플랜과 같은 원칙)
- **D2. 헤더 `↑` 와 `공유` 버튼은 #6 이 붙인다.** 같은 원칙. #6 은 `WorkoutShareUI` 를 그대로 쓰므로 자리만 비워 둔다
- **D3. 값이 없는 지표는 `–` 로 자리를 지킨다.** 공유 카드는 행을 빼지만(스펙 06) 상세는 3칸 격자라 빼면 칸 폭이 흔들린다.
  건강 앱에서 가져온 기록은 심박이 없는 경우가 흔하다
- **D4. 부위는 `bodyPartsRaw: [String] = []` 로 저장한다.** `Segment.kindRaw` 처럼 enum 의 rawValue 를 쓴다(CloudKit 이 enum 을 직접
  저장하지 못한다). 비트마스크(`Int`)보다 저장소를 열어 봤을 때 읽히고, 케이스 순서를 바꿔도 깨지지 않는다.
  읽을 때는 `BodyPart.allCases` 순서로 정렬해 탭한 순서와 무관하게 `가슴 · 팔` 로 읽힌다
- **D5. 목록 행의 부위는 칩이 아니라 `가슴 · 팔` 한 줄 텍스트**로 구간 칩 아래에 둔다. 구간 칩 2개 + 부위 칩 최대 6개를 한 줄에 두면
  좁은 폰에서 kcal 을 밀어내므로 기존 행의 정보 밀도를 유지한다. 6개 모두 선택한 경우와 큰 글자 크기에서 잘림도 확인한다
- **D6. 메모는 포커스가 빠질 때와 시트가 닫힐 때 저장한다.** 키 입력마다 `save()` 하지 않는다. 메모에 포커스가 가면 시트를
  `.large` 로 올려 키보드에 가리지 않게 하고, 섹션 제목 옆에 `완료` 를 띄운다
- **D7. 워치가 같은 기록을 다시 보내면 부위·메모를 이어받는다.** 아키텍처 3절 *"부위·메모를 잃지 않고 갱신한다"* 를 지금 지킨다.
  import 는 이미 가진 `healthKitUUID` 를 건드리지 않아(`WorkoutImportPlanner`) 손볼 곳이 없다
- **D8. 시트 안의 저장 실패는 시트가 직접 알린다.** 앱 전역 알림은 `ContentView`(TabView) 에 붙어 있어 시트가 떠 있는 동안 표시되지
  않는다. 문구는 `AppAlert.editFailed` 로 한 곳에 둔다

### 범위 밖

- 홈 "최근 기록 2개" → 시트 진입 — 홈 대시보드(#7)가 만든다. 그때 시트를 그대로 띄운다
- 달력 날짜 탭 → 시트 — #8
- 워치 `endedAt` 지연 수정 (TODO *"종료 시각 지연 수정"*) — `WatchApp/` 을 건드리는 별건이다. 헤더의 끝 시각이
  HealthKit 마무리 시간(수 초)만큼 늦을 수 있지만 분 단위 표기라 거의 드러나지 않는다. 이 플랜 다음에 따로 한다

## 화면·표시 규칙

### 헤더

| 항목 | 규칙 | 예 |
|---|---|---|
| 날짜 | 시작 시각, `M월 d일 (E)`. 올해가 아니면 `yyyy년 M월 d일 (E)` | `9월 28일 (월)` · `2025년 12월 30일 (화)` |
| 시간대 범위 | `B h:mm – h:mm`. 끝의 시간대 이름(`B`)이 시작과 **다를 때만** 붙인다 | `저녁 7:12 – 8:24` · `저녁 8:30 – 밤 9:40` |
| 끝 시각 | `endedAt`. 없으면 `startedAt + totalSeconds` | |

`B` 는 ICU 의 유연한 시간대 이름이다 — `ko_KR` 에서 `오전` · `오후` · `저녁` · `밤` 등으로 찍힌다. 스펙의 `저녁 7:12` 가 이것이다.
로케일은 `ko_KR` 고정 (목록과 같다).

### 요약 3칸

| 칸 | 값 | 없을 때 |
|---|---|---|
| 총 시간 | `totalSeconds / 60` 내림 + `분` → `72분`. **60초 미만은 `1분 미만`** | — (항상 있다) |
| kcal | `totalCalories` 반올림 → `412` | `–` |
| 평균 심박 | `averageHeartRate` 반올림 → `128` | `–` |

`totalCalories` 를 쓰는 이유는 목록 행과 같다 — 잔디의 칼로리 기준과 숫자가 갈리지 않는다.

### 운동 구성

- 바: `orderedSegments` 중 **길이가 0보다 큰 구간**을 순서대로, 길이 비율대로. 근력 `accent` · 유산소 `cardio`
- 문구: 목록 행 칩과 **같은 규칙**(`RecordListBuilder.segmentChips`) — 종류별 합계, 처음 나온 순서, 1분 미만 종류 제외 — 를 ` · ` 로 잇는다
- 그릴 구간이 없으면 섹션(제목·바·문구)을 통째로 뺀다

### 부위 · 메모 · 삭제

- 부위: 3열 × 2행 캡슐. 선택 = `accent` 채움 + `bg` 글자, 미선택 = `surface2` 채움 + `text` 글자. 탭 즉시 저장
- 메모: 여러 줄 `TextField`(3–8줄). 앞뒤 공백을 자르고, 비면 `nil` 로 저장한다
- 삭제: 시트 맨 아래 붉은 버튼 → 확인 다이얼로그(목록과 같은 문구 *"건강 앱의 운동 기록은 그대로 남아요."*) → 시트를 내린 뒤 지운다

### 시트

- `presentationDetents([.medium, .large])`, 그랩 핸들 표시, 배경 `HaruchiPalette.bg`
- 내용은 `ScrollView` — `.medium` 에서 넘치는 부분은 스크롤로 본다

| 알림 | 제목 | 본문 |
|---|---|---|
| `editFailed` (신규) | 변경 내용을 저장하지 못했어요 | 잠시 후 다시 시도해 주세요. |

## 파일별 작업

| 파일 | 변경 | Task |
|---|---|---|
| `Apps/HaruchiFit/Shared/Models/BodyPart.swift` | 생성 | 1 |
| `Apps/HaruchiFit/Shared/Persistence/WorkoutRecord.swift` | 수정 — `bodyPartsRaw` · `bodyParts` | 1 |
| `Apps/HaruchiFit/Shared/Persistence/WorkoutRecord+Annotations.swift` | 생성 | 1 |
| `Apps/HaruchiFit/watchosTests/Models/WorkoutRecordAnnotationTests.swift` | 생성 | 1 |
| `Apps/HaruchiFit/watchosTests/Support/GrassFixture.swift` | 수정 — 테스트 저장소 격리 (Ralli PR #38 처방) | 1 |
| `Apps/HaruchiFit/iOSApp/iOSApp.swift` | 수정 — `save(_:)` 가 부위·메모를 이어받는다 | 1 |
| `Apps/HaruchiFit/Shared/Models/RecordDetailSummary.swift` | 생성 | 2 |
| `Apps/HaruchiFit/Shared/Models/RecordDetailBuilder.swift` | 생성 | 2 |
| `Apps/HaruchiFit/Shared/Models/RecordListBuilder.swift` | 수정 — 칩·포매터를 내부 공개, 행에 부위 | 2 · 3 |
| `Apps/HaruchiFit/watchosTests/Models/RecordDetailBuilderTests.swift` | 생성 | 2 |
| `Apps/HaruchiFit/Shared/Models/RecordListRow.swift` | 수정 — `bodyPartsText` | 3 |
| `Apps/HaruchiFit/watchosTests/Models/RecordListBuilderTests.swift` | 수정 — 테스트 1개 추가 | 3 |
| `Apps/HaruchiFit/iOSApp/Features/Records/Components/RecordRow.swift` | 수정 — 부위 줄 | 3 |
| `Apps/HaruchiFit/iOSApp/AppAlert.swift` | 수정 — `editFailed` | 4 |
| `Apps/HaruchiFit/iOSApp/Features/Records/Detail/RecordDetailViewModel.swift` | 생성 | 4 |
| `Apps/HaruchiFit/iOSApp/Features/Records/Detail/RecordDetailView.swift` | 생성 | 4 |
| `Apps/HaruchiFit/iOSApp/Features/Records/Detail/Components/SegmentTimelineBar.swift` | 생성 | 4 |
| `Apps/HaruchiFit/iOSApp/Features/Records/Detail/Components/BodyPartChips.swift` | 생성 | 4 |
| `Apps/HaruchiFit/iOSApp/Features/Records/RecordsView.swift` | 수정 — 행 탭 · 시트 · 삭제 후처리 | 4 |
| `Apps/HaruchiFit/CLAUDE.md` | 수정 | 5 |
| `Apps/HaruchiFit/docs/specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md` | 수정 | 5 |
| `TODO.md` | 수정 | 5 |

- `BodyPart` 는 `Shared/Models/` 에 둔다. 워치 앱은 쓰지 않지만 `WorkoutRecord`(`Shared/Persistence/`)가 참조하므로 같은 두 타깃에
  붙어야 한다. 컴플리케이션은 `WorkoutRecord` 를 모르므로 `Common/` 에 둘 이유가 없다
- 시트는 기록 탭 안의 화면이라 `Features/Records/Detail/` 서브폴더에 둔다 (루트 `CLAUDE.md` — Feature 하위 화면 단위 서브폴더 허용).
  #7 홈·#8 달력도 이 시트를 **지금 시그니처 그대로**(`record` · `context` · `onDelete`) 띄운다. 루트 `CLAUDE.md` "ViewModel 전달" 이
  다른 Feature 의 화면을 값과 콜백으로 조합하는 것을 허용하고, 시트는 `RecordsViewModel` 을 받지 않으므로 홈이 기록 Feature 의 VM 을 알게 되지 않는다.
  `onDelete` 를 각자의 삭제 경로에 잇는 일은 띄우는 쪽 화면이 한다
- `SegmentTimelineBar` 는 워치 `SegmentBar` 의 **복제본**이다. 그쪽 주석이 *"두 곳에서 필요해질 때 `WorkoutUI/Shared/` 로 올리거나 복제한다"* 고
  미뤄 둔 결정을 복제로 닫는다 — Kit 으로 올리면 Kit 이 근력/유산소라는 도메인을 알게 되고(루트 `CLAUDE.md` "코어는 도메인을 모른다"),
  두 바는 색 토큰부터 다르다(워치 `BrandColor` / iOS `HaruchiPalette`). 워치 파일은 건드리지 않는다
- **SwiftData 경량 마이그레이션** — 기본값이 있는 속성 추가라 자동으로 넘어간다. Task 4 Step 8 에서 기존 데이터가 있는 시뮬레이터에
  덮어 설치해 확인한다

---

## Task 0: 작업 트리

- [x] **Step 1: 워크트리와 브랜치를 만든다** (루트 `CLAUDE.md` 워크트리 규약 — 형제 폴더)

**기존 워크트리를 재사용한다.** 2026-10-06 확인 결과 `feat/haruchi-record-detail` 과 메인 체크아웃 모두
`a78a6bb` (PR #39 merge)다. 생성 명령은 아래에 기록하되 다시 실행하지 않는다.
새 출발이 필요할 때는 로컬 `main` 대신 확인된 `origin/main` 에서 출발한다.

```bash
git -C /Users/yj/Workspace/Projects/yj-apps fetch origin
git -C /Users/yj/Workspace/Projects/yj-apps worktree add \
  ../yj-apps-worktrees/haruchi-record-detail -b feat/haruchi-record-detail origin/main
git -C ../yj-apps-worktrees/haruchi-record-detail log --oneline -1
```

Expected: 마지막 줄이 `origin/main` 의 최신 커밋과 같다 (2026-10-06 기준 `a78a6bb Merge pull request #39 …` 이후).

- [x] **Step 2: 이 플랜 문서를 워크트리로 옮긴다**

문서는 이미 대상 워크트리에 있다. 아래 이동 명령은 이력이며 다시 실행하지 않는다.
사용자 검토 전에는 커밋하지 않는다. 승인 후 브랜치와 함께 PR 에 실린다.

```bash
mkdir -p ../yj-apps-worktrees/haruchi-record-detail/Apps/HaruchiFit/docs/plans/ios/2026
mv Apps/HaruchiFit/docs/plans/ios/2026/2026-10-06-record-detail.md \
   ../yj-apps-worktrees/haruchi-record-detail/Apps/HaruchiFit/docs/plans/ios/2026/
```

이후 모든 명령은 `../yj-apps-worktrees/haruchi-record-detail` 루트에서 실행한다.

- [ ] **Step 3: 기준 상태를 확인한다**

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFitWatchTests -destination "id=$WATCH" test
```

Expected: `** TEST SUCCEEDED **`. 실패하면 이번 변경 전의 문제이므로 멈추고 보고한다.

---

## Task 1: 부위 필드와 편집 규칙 (TDD) · 재전송 시 이어받기

**Files:**
- Create: `Apps/HaruchiFit/Shared/Models/BodyPart.swift`
- Modify: `Apps/HaruchiFit/Shared/Persistence/WorkoutRecord.swift:29` (메모 아래)
- Create: `Apps/HaruchiFit/Shared/Persistence/WorkoutRecord+Annotations.swift`
- Test: `Apps/HaruchiFit/watchosTests/Models/WorkoutRecordAnnotationTests.swift`
- Modify: `Apps/HaruchiFit/watchosTests/Support/GrassFixture.swift:5-20` (Step 0 — 저장소 격리)
- Modify: `Apps/HaruchiFit/iOSApp/iOSApp.swift:65-71` (`save(_:)` 의 `do` 블록)

**Interfaces:**
- Consumes: 테스트 픽스처 `GrassFixture.makeContext()` · `.record(in:startedAt:totalSeconds:totalCalories:segments:)` · `.date(_:_:_:_:_:)`
- Produces:
  - `enum BodyPart: String, Codable, CaseIterable { case chest, back, shoulders, arms, legs, core; var title: String }`
  - `WorkoutRecord.bodyPartsRaw: [String]` (저장 속성, 기본 `[]`)
  - `WorkoutRecord.bodyParts: [BodyPart]` — 읽기 전용, `BodyPart.allCases` 순서
  - `WorkoutRecord.toggle(_ part: BodyPart)`
  - `WorkoutRecord.setMemo(_ text: String)`
  - `WorkoutRecord.adoptAnnotations(from old: WorkoutRecord)`

- [ ] **Step 0: 테스트 저장소를 격리한다** (Ralli PR #38 처방)

지금 `GrassFixture.makeContext()` 는 **이름 없는 인메모리 설정**이고 컨테이너를 붙들지 않는다. Ralli 에서는 이름 없는 설정이
모두 `default` 저장소를 가리켜 테스트끼리 섞였다. 하루치 워치 테스트 호스트엔 iCloud 권한이 없어 지금은 통과하지만,
이 Task 의 `adoptAnnotationsSurvivesReplacement` 처럼 **저장소 전체 개수를 세는 검사**는 섞이는 순간 흔들린다.

`GrassFixture.swift` — 타입 doc 주석의 *"인메모리 컨테이너를 띄운다"* 문단과 `makeContext()` 를 바꾼다:

```swift
/// **테스트마다 격리된 인메모리 저장소를 띄운다** (Ralli PR #38 `TestPersistence` 와 같은 처방).
/// - 이름을 매번 새로 준다 — 이름 없는 설정은 모두 `default` 저장소를 가리켜 테스트끼리 섞인다
/// - `cloudKitDatabase: .none` — 나중에 iCloud 권한이 붙어도 인메모리 저장소에 미러링이 붙지 않게
/// - 컨테이너를 정적 배열에 보관한다 — 테스트가 컨텍스트만 들고 있어도 저장소가 먼저 풀리지 않게
///
/// `@Model` 인스턴스를 컨텍스트 없이 만들면 to-many 관계 대입의 동작이 보장되지 않는다.
/// 컨테이너 하나 띄우는 비용이 그 불확실성보다 싸다.
```

```swift
    private static var retainedContainers: [ModelContainer] = []

    static func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(UUID().uuidString,
                                               isStoredInMemoryOnly: true,
                                               cloudKitDatabase: .none)
        let container = try ModelContainer(for: WorkoutRecord.self, Segment.self,
                                           configurations: configuration)
        retainedContainers.append(container)
        return ModelContext(container)
    }
```

**타임존을 고정한다** 문단은 그대로 둔다. 기존 워치 테스트 전부가 이 픽스처를 쓰므로 바로 회귀를 본다:

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFitWatchTests -destination "id=$WATCH" test
```

Expected: `** TEST SUCCEEDED **`, Task 0 Step 3 과 같은 테스트 수. 실패하면 픽스처 변경 탓이므로 멈추고 보고한다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`Apps/HaruchiFit/watchosTests/Models/WorkoutRecordAnnotationTests.swift`:

```swift
import Foundation
@testable import HaruchiFit_Watch_App
import SwiftData
import Testing

/// 부위 태그와 메모 (제품 스펙 04 · D1 · D6). 둘 다 SwiftData 가 원본이라
/// HealthKit 에서 되살릴 수 없다 — 잃으면 끝이다.
@MainActor
struct WorkoutRecordAnnotationTests {
    private func makeRecord(in context: ModelContext) -> WorkoutRecord {
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 6), totalSeconds: 600)
    }

    @Test("부위는 탭할 때마다 켜고 끈다")
    func toggleFlipsPart() throws {
        let context = try GrassFixture.makeContext()
        let record = makeRecord(in: context)

        record.toggle(.chest)
        record.toggle(.arms)
        #expect(record.bodyParts == [.chest, .arms])

        record.toggle(.chest)
        #expect(record.bodyParts == [.arms])
    }

    @Test("부위는 탭한 순서가 아니라 고정 순서로 읽힌다")
    func partsReadInCanonicalOrder() throws {
        let context = try GrassFixture.makeContext()
        let record = makeRecord(in: context)

        record.toggle(.core)
        record.toggle(.chest)
        record.toggle(.legs)

        #expect(record.bodyParts == [.chest, .legs, .core])
    }

    @Test("모르는 값은 버리고 읽는다")
    func unknownRawValuesAreIgnored() throws {
        let context = try GrassFixture.makeContext()
        let record = makeRecord(in: context)

        record.bodyPartsRaw = ["back", "neck"]

        #expect(record.bodyParts == [.back])
    }

    @Test("메모는 앞뒤 공백을 자르고, 비면 nil 로 둔다")
    func memoIsTrimmedAndEmptyBecomesNil() throws {
        let context = try GrassFixture.makeContext()
        let record = makeRecord(in: context)

        record.setMemo("  벤치프레스 5×5, 딥스 \n")
        #expect(record.memo == "벤치프레스 5×5, 딥스")

        record.setMemo("   \n ")
        #expect(record.memo == nil)
    }

    @Test("워치가 같은 기록을 다시 보내도 부위와 메모를 이어받는다")
    func adoptAnnotationsSurvivesReplacement() throws {
        let context = try GrassFixture.makeContext()
        let old = makeRecord(in: context)
        old.toggle(.back)
        old.setMemo("데드리프트")
        try context.save()

        // iOSApp.save(_:) 의 upsert(replacing:) 와 같은 순서 — 지우고 새로 넣는다
        let fresh = WorkoutRecord(startedAt: old.startedAt, totalSeconds: 700)
        fresh.adoptAnnotations(from: old)
        context.delete(old)
        context.insert(fresh)
        try context.save()

        let stored = try context.fetch(FetchDescriptor<WorkoutRecord>())
        #expect(stored.count == 1)
        #expect(stored.first?.totalSeconds == 700)
        #expect(stored.first?.bodyParts == [.back])
        #expect(stored.first?.memo == "데드리프트")
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFitWatchTests -destination "id=$WATCH" \
  test -only-testing:HaruchiFitWatchTests/WorkoutRecordAnnotationTests
```

Expected: 컴파일 실패 — `value of type 'WorkoutRecord' has no member 'toggle'`

- [ ] **Step 3: 부위 enum 을 만든다**

`Apps/HaruchiFit/Shared/Models/BodyPart.swift`:

```swift
import Foundation

/// 근력 대상 부위 6개 (제품 스펙 D1). 유산소는 세그먼트로 이미 기록되므로 넣지 않는다.
///
/// **케이스 순서가 화면 순서다** — 칩 배치와 `가슴 · 팔` 같은 표기가 모두 `allCases` 를 따른다.
/// 저장은 rawValue 라 순서를 바꿔도 기존 기록은 깨지지 않는다.
enum BodyPart: String, Codable, CaseIterable {
    case chest
    case back
    case shoulders
    case arms
    case legs
    case core

    var title: String {
        switch self {
        case .chest: "가슴"
        case .back: "등"
        case .shoulders: "어깨"
        case .arms: "팔"
        case .legs: "하체"
        case .core: "코어"
        }
    }
}
```

- [ ] **Step 4: 레코드에 부위 필드를 더한다**

`WorkoutRecord.swift` — `var memo: String?` 아래에 추가:

```swift
    /// 태그한 부위의 `BodyPart` rawValue (D1 — 멀티). enum 배열을 직접 저장하지 않는 것은 `Segment.kindRaw` 와 같은 이유다.
    /// 화면은 `bodyParts` 를 읽는다. 기본값이 있어 기존 저장소는 경량 마이그레이션으로 넘어온다.
    var bodyPartsRaw: [String] = []
```

같은 파일 `source` 계산 속성 아래에 추가:

```swift
    /// 태그한 부위. **탭한 순서가 아니라 `BodyPart.allCases` 순서**이고, 모르는 값은 버린다.
    var bodyParts: [BodyPart] {
        BodyPart.allCases.filter { bodyPartsRaw.contains($0.rawValue) }
    }
```

`init` 은 바꾸지 않는다 — 새 기록은 언제나 태그 없이 생긴다.

- [ ] **Step 5: 편집 규칙을 만든다**

`Apps/HaruchiFit/Shared/Persistence/WorkoutRecord+Annotations.swift`:

```swift
import Foundation

/// 사용자가 붙이는 부위·메모 (제품 스펙 04 · D1 · D6). **HealthKit 에 자리가 없어 여기가 원본이다** —
/// 레코드를 갈아끼우는 경로는 반드시 `adoptAnnotations(from:)` 로 넘겨받아야 한다.
///
/// 저장(`save()`)은 하지 않는다. 호출부가 자기 컨텍스트에서 한다.
extension WorkoutRecord {
    /// 탭 = 토글 (D1). 고정 순서로 다시 쓰므로 모르는 값은 이때 사라진다.
    func toggle(_ part: BodyPart) {
        var selected = Set(bodyParts)
        if selected.contains(part) {
            selected.remove(part)
        } else {
            selected.insert(part)
        }
        bodyPartsRaw = BodyPart.allCases.filter(selected.contains).map(\.rawValue)
    }

    /// 앞뒤 공백을 자르고, 남는 게 없으면 메모가 없는 것으로 둔다 — 플레이스홀더가 다시 보여야 한다.
    func setMemo(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        memo = trimmed.isEmpty ? nil : trimmed
    }

    /// 같은 워크아웃의 이전 레코드에서 부위·메모를 넘겨받는다.
    /// 워치 재전송은 레코드를 **지우고 새로 넣으므로**(`PersistenceService.upsert`) 이걸 거치지 않으면 사라진다.
    func adoptAnnotations(from old: WorkoutRecord) {
        bodyPartsRaw = old.bodyPartsRaw
        memo = old.memo
    }
}
```

- [ ] **Step 6: 테스트가 통과하는지 확인한다**

Step 2 명령을 다시 실행한다. Expected: `WorkoutRecordAnnotationTests` 5개 통과, `** TEST SUCCEEDED **`

- [ ] **Step 7: 워치 저장이 부위·메모를 이어받게 한다**

`iOSApp.swift` — `save(_:)` 의 `do` 블록을 바꾼다:

```swift
        do {
            if let uuid = message.healthKitUUID {
                let replacing = #Predicate<WorkoutRecord> { $0.healthKitUUID == uuid }
                // 재전송이면 사용자가 붙인 부위·메모를 넘겨받는다 — upsert 는 지우고 새로 넣는다 (아키텍처 3절)
                if let existing = try store.fetch(matching: replacing).first {
                    record.adoptAnnotations(from: existing)
                }
                try store.upsert(record, replacing: replacing)
            } else {
                try store.upsert(record)
            }
        } catch {
```

`catch` 이하는 그대로다. 메서드 doc 주석의 *"그 키로 기존 기록을 갈아끼우고"* 뒤에 *"부위·메모는 넘겨받는다"* 를 덧붙인다.

- [ ] **Step 8: 전체 워치 테스트 · iOS 빌드**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFitWatchTests -destination "id=$WATCH" test
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFit -destination "id=$IOS" build
```

Expected: `** TEST SUCCEEDED **` · `** BUILD SUCCEEDED **`

- [ ] **Step 9: 커밋**

```bash
git add Apps/HaruchiFit/Shared/Models/BodyPart.swift \
        Apps/HaruchiFit/Shared/Persistence/WorkoutRecord.swift \
        Apps/HaruchiFit/Shared/Persistence/WorkoutRecord+Annotations.swift \
        Apps/HaruchiFit/watchosTests/Models/WorkoutRecordAnnotationTests.swift \
        Apps/HaruchiFit/watchosTests/Support/GrassFixture.swift \
        Apps/HaruchiFit/iOSApp/iOSApp.swift
git commit -m "✨ 하루치 기록에 부위 태그를 더하고 워치 재전송에도 부위·메모를 지킨다"
```

---

## Task 2: 기록 상세 표시 규칙 (TDD)

**Files:**
- Create: `Apps/HaruchiFit/Shared/Models/RecordDetailSummary.swift`
- Create: `Apps/HaruchiFit/Shared/Models/RecordDetailBuilder.swift`
- Modify: `Apps/HaruchiFit/Shared/Models/RecordListBuilder.swift:55-83` (칩 계산·포매터를 내부 공개로 뺀다)
- Test: `Apps/HaruchiFit/watchosTests/Models/RecordDetailBuilderTests.swift`

**Interfaces:**
- Consumes: `WorkoutRecord.startedAt` · `.endedAt` · `.totalSeconds` · `.totalCalories` · `.averageHeartRate` · `.orderedSegments`, `RecordListRow.Chip`
- Produces:
  - `struct RecordDetailSummary { let dateTitle, timeRangeTitle, durationText, caloriesText, heartRateText: String; let spans: [Span]; let compositionText: String? }`
  - `struct RecordDetailSummary.Span: Hashable { let kind: SegmentKind; let seconds: Int }`
  - `static func RecordDetailBuilder.summary(for: WorkoutRecord, now: Date, calendar: Calendar, locale: Locale) -> RecordDetailSummary`
  - `static func RecordListBuilder.segmentChips(for: WorkoutRecord) -> [RecordListRow.Chip]` (기존 private 로직을 내부 공개)
  - `static func RecordListBuilder.formatter(_ format: String, calendar: Calendar, locale: Locale) -> DateFormatter` (private → internal)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`Apps/HaruchiFit/watchosTests/Models/RecordDetailBuilderTests.swift`:

```swift
import Foundation
@testable import HaruchiFit_Watch_App
import SwiftData
import Testing

/// 기록 상세 하프 시트의 표기 (제품 스펙 04). 화면이 그대로 찍을 문자열까지 여기서 끝낸다.
@MainActor
struct RecordDetailBuilderTests {
    private let now = GrassFixture.date(2026, 10, 6)

    private func summary(_ record: WorkoutRecord) -> RecordDetailSummary {
        RecordDetailBuilder.summary(for: record,
                                    now: now,
                                    calendar: GrassFixture.seoul,
                                    locale: Locale(identifier: "ko_KR"))
    }

    // MARK: - 헤더

    @Test("헤더는 날짜와 시간대 범위다. 같은 시간대면 끝의 시간대 이름을 뺀다")
    func headerOmitsRepeatedPeriod() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28, 19, 12), totalSeconds: 4320)
        record.endedAt = GrassFixture.date(2026, 9, 28, 20, 24)

        let result = summary(record)
        #expect(result.dateTitle == "9월 28일 (월)")
        #expect(result.timeRangeTitle == "저녁 7:12 – 8:24")
    }

    @Test("시간대가 바뀌면 끝에도 시간대 이름을 붙인다")
    func headerKeepsChangedPeriod() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28, 20, 30), totalSeconds: 4200)
        record.endedAt = GrassFixture.date(2026, 9, 28, 21, 40)

        #expect(summary(record).timeRangeTitle == "저녁 8:30 – 밤 9:40")
    }

    @Test("종료 시각이 없으면 시작에 총 시간을 더한다")
    func missingEndUsesTotalSeconds() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28, 7, 0), totalSeconds: 3600)

        #expect(summary(record).timeRangeTitle == "오전 7:00 – 8:00")
    }

    @Test("다른 해의 기록은 날짜에 연도를 붙인다")
    func otherYearDateCarriesYear() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: GrassFixture.date(2025, 12, 30), totalSeconds: 600)

        #expect(summary(record).dateTitle == "2025년 12월 30일 (화)")
    }

    // MARK: - 요약 3칸

    @Test("요약 3칸은 분 · 반올림 kcal · 반올림 심박이다")
    func statsAreMinutesAndRoundedValues() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28),
                                         totalSeconds: 4320, totalCalories: 412.4)
        record.averageHeartRate = 127.6

        let result = summary(record)
        #expect(result.durationText == "72분")
        #expect(result.caloriesText == "412")
        #expect(result.heartRateText == "128")
    }

    @Test("값이 없는 지표는 대시로 자리를 지킨다")
    func missingMetricsKeepTheirPlace() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28), totalSeconds: 600)

        let result = summary(record)
        #expect(result.caloriesText == "–")
        #expect(result.heartRateText == "–")
    }

    @Test("1분이 안 되는 기록은 0분이 아니라 1분 미만이다")
    func subMinuteRecordSaysUnderOneMinute() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28), totalSeconds: 40)

        #expect(summary(record).durationText == "1분 미만")
    }

    // MARK: - 운동 구성

    @Test("운동 구성은 구간 순서대로 바를 만들고 종류별 합계를 붙인다")
    func compositionFollowsSegmentOrder() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context,
                                         startedAt: GrassFixture.date(2026, 9, 28),
                                         totalSeconds: 4320,
                                         segments: [(.strength, 0, 1800), (.cardio, 1800, 1080), (.strength, 2880, 1440)])

        let result = summary(record)
        #expect(result.spans.map(\.kind) == [.strength, .cardio, .strength])
        #expect(result.spans.map(\.seconds) == [1800, 1080, 1440])
        #expect(result.compositionText == "근력 54분 · 유산소 18분")
    }

    @Test("구간이 없거나 길이가 0이면 바와 구성 문구를 만들지 않는다")
    func emptyCompositionHasNoBar() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context,
                                         startedAt: GrassFixture.date(2026, 9, 28),
                                         totalSeconds: 600,
                                         segments: [(.strength, 0, 0)])

        let result = summary(record)
        #expect(result.spans.isEmpty)
        #expect(result.compositionText == nil)
    }
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFitWatchTests -destination "id=$WATCH" \
  test -only-testing:HaruchiFitWatchTests/RecordDetailBuilderTests
```

Expected: 컴파일 실패 — `cannot find 'RecordDetailBuilder' in scope`

- [ ] **Step 3: 목록 빌더의 칩 계산과 포매터를 꺼낸다**

`RecordListBuilder.swift` — `row(for:formatter:)` 의 칩 계산 부분을 새 메서드로 옮기고 `row` 가 그걸 부르게 한다:

```swift
    /// 구간 종류별 합계를 **처음 나온 순서**로. 1분 미만인 종류는 뺀다 — `유산소 0분` 은 정보가 아니다.
    /// 기록 상세의 운동 구성 문구도 이걸 쓴다 — 두 화면의 숫자가 갈리지 않게.
    static func segmentChips(for record: WorkoutRecord) -> [RecordListRow.Chip] {
        var order: [SegmentKind] = []
        var seconds: [SegmentKind: Int] = [:]
        for segment in record.orderedSegments {
            if seconds[segment.kind] == nil { order.append(segment.kind) }
            seconds[segment.kind, default: 0] += segment.durationSeconds
        }
        return order.compactMap { kind -> RecordListRow.Chip? in
            let minutes = (seconds[kind] ?? 0) / 60
            return minutes > 0 ? RecordListRow.Chip(kind: kind, minutes: minutes) : nil
        }
    }

    private static func row(for record: WorkoutRecord, formatter: DateFormatter) -> RecordListRow {
        // 잔디 칼로리 기준(GrassAggregator)과 같은 값을 쓴다
        let calories = record.totalCalories.map { "\(Int($0.rounded())) kcal" }
        return RecordListRow(id: record.persistentModelID,
                             record: record,
                             dateTitle: formatter.string(from: record.startedAt),
                             chips: segmentChips(for: record),
                             caloriesText: calories)
    }
```

맨 아래 `private static func formatter(...)` 의 `private` 를 지운다 (상세 빌더가 같은 설정을 쓴다).

- [ ] **Step 4: 요약 모델을 만든다**

`Apps/HaruchiFit/Shared/Models/RecordDetailSummary.swift`:

```swift
import Foundation

/// 기록 상세 하프 시트가 찍을 값 (제품 스펙 04). 문자열까지 여기서 끝낸다 — View 에 규칙을 두면
/// iOS 테스트 타깃이 없어 아무도 검증하지 못한다.
struct RecordDetailSummary {
    /// `9월 28일 (월)`. 올해가 아니면 연도가 붙는다.
    let dateTitle: String
    /// `저녁 7:12 – 8:24`
    let timeRangeTitle: String
    /// `72분` · `1분 미만`
    let durationText: String
    /// 값이 없으면 `RecordDetailBuilder.placeholder` — 3칸 격자가 흔들리지 않게 자리를 지킨다.
    let caloriesText: String
    let heartRateText: String
    /// 운동 구성 바. 길이가 0인 구간은 뺐다. 비어 있으면 섹션을 그리지 않는다.
    let spans: [Span]
    /// `근력 54분 · 유산소 18분`. 1분 이상인 종류가 없으면 nil.
    let compositionText: String?

    /// 바의 한 칸. 전환 횟수는 담지 않는다 (D7) — 칸의 개수가 곧 전환 횟수지만 숫자로 내보내지 않는다.
    struct Span: Hashable {
        let kind: SegmentKind
        let seconds: Int
    }
}
```

- [ ] **Step 5: 빌더를 만든다**

`Apps/HaruchiFit/Shared/Models/RecordDetailBuilder.swift`:

```swift
import Foundation

/// 기록 하나를 상세 시트의 표기로 바꾼다 (제품 스펙 04). 날짜·칩 규칙은 목록(`RecordListBuilder`)과 같다.
enum RecordDetailBuilder {
    /// 값이 없는 지표 자리. 공유 카드처럼 행을 빼지 않는다 — 상세는 3칸 격자다 (플랜 결정 D3).
    static let placeholder = "–"

    static func summary(for record: WorkoutRecord,
                        now: Date = Date(),
                        calendar: Calendar = .current,
                        locale: Locale = Locale(identifier: "ko_KR")) -> RecordDetailSummary
    {
        let sameYear = calendar.component(.year, from: record.startedAt) == calendar.component(.year, from: now)
        let dateFormatter = RecordListBuilder.formatter(sameYear ? "M월 d일 (E)" : "yyyy년 M월 d일 (E)",
                                                        calendar: calendar, locale: locale)
        // 워치 기록의 endedAt 은 정지를 포함한 벽시계다 — 총 시간과 같다고 가정하지 않는다
        let end = record.endedAt ?? record.startedAt.addingTimeInterval(TimeInterval(record.totalSeconds))
        let chips = RecordListBuilder.segmentChips(for: record)

        return RecordDetailSummary(
            dateTitle: dateFormatter.string(from: record.startedAt),
            timeRangeTitle: timeRange(from: record.startedAt, to: end, calendar: calendar, locale: locale),
            durationText: duration(record.totalSeconds),
            // 잔디 칼로리 기준(GrassAggregator)·목록 행과 같은 값
            caloriesText: record.totalCalories.map { "\(Int($0.rounded()))" } ?? placeholder,
            heartRateText: record.averageHeartRate.map { "\(Int($0.rounded()))" } ?? placeholder,
            spans: record.orderedSegments
                .filter { $0.durationSeconds > 0 }
                .map { RecordDetailSummary.Span(kind: $0.kind, seconds: $0.durationSeconds) },
            compositionText: chips.isEmpty ? nil : chips.map(\.text).joined(separator: " · ")
        )
    }

    /// `저녁 7:12 – 8:24`. `B` 는 ICU 의 유연한 시간대 이름(오전·오후·저녁·밤…)이다.
    /// 끝의 시간대 이름은 시작과 **다를 때만** 붙인다.
    private static func timeRange(from start: Date, to end: Date,
                                  calendar: Calendar, locale: Locale) -> String
    {
        let withPeriod = RecordListBuilder.formatter("B h:mm", calendar: calendar, locale: locale)
        let withoutPeriod = RecordListBuilder.formatter("h:mm", calendar: calendar, locale: locale)
        let period = RecordListBuilder.formatter("B", calendar: calendar, locale: locale)
        let samePeriod = period.string(from: start) == period.string(from: end)
        return "\(withPeriod.string(from: start)) – \((samePeriod ? withoutPeriod : withPeriod).string(from: end))"
    }

    /// 분 내림. **60초 미만은 `0분` 이 아니라 `1분 미만`** — 0 은 기록이 없다는 뜻으로 읽힌다.
    private static func duration(_ seconds: Int) -> String {
        seconds < 60 ? "1분 미만" : "\(seconds / 60)분"
    }
}
```

- [ ] **Step 6: 테스트가 통과하는지 확인한다**

Step 2 명령을 다시 실행한다. Expected: `RecordDetailBuilderTests` 9개 통과.
시간대 이름 테스트가 실패하면 시뮬레이터 ICU 의 `B` 출력이 다른 것이다 — 기대값을 바꾸지 말고 실제 출력을 보고하고 멈춘다
(스펙 문구 `저녁 7:12` 를 지킬 다른 방법을 정해야 한다).

- [ ] **Step 7: 전체 워치 테스트로 회귀를 확인한다** (`RecordListBuilderTests` 가 칩 추출 뒤에도 그대로 통과해야 한다)

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFitWatchTests -destination "id=$WATCH" test
```

Expected: `** TEST SUCCEEDED **`

- [ ] **Step 8: 커밋**

```bash
git add Apps/HaruchiFit/Shared/Models/RecordDetailSummary.swift \
        Apps/HaruchiFit/Shared/Models/RecordDetailBuilder.swift \
        Apps/HaruchiFit/Shared/Models/RecordListBuilder.swift \
        Apps/HaruchiFit/watchosTests/Models/RecordDetailBuilderTests.swift
git commit -m "✨ 하루치 기록 상세의 헤더·요약·운동 구성 표기 규칙을 추가한다"
```

---

## Task 3: 목록 행에 부위 표시 (TDD)

**Files:**
- Modify: `Apps/HaruchiFit/Shared/Models/RecordListRow.swift` (`caloriesText` 아래)
- Modify: `Apps/HaruchiFit/Shared/Models/RecordListBuilder.swift` (`row(for:formatter:)`)
- Modify: `Apps/HaruchiFit/watchosTests/Models/RecordListBuilderTests.swift` (테스트 1개 추가)
- Modify: `Apps/HaruchiFit/iOSApp/Features/Records/Components/RecordRow.swift`

**Interfaces:**
- Consumes: Task 1 의 `WorkoutRecord.bodyParts` · `.toggle(_:)`, `BodyPart.title`
- Produces: `RecordListRow.bodyPartsText: String?` — `가슴 · 팔`, 태그가 없으면 nil

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`RecordListBuilderTests.swift` 맨 끝(`caloriesText` 테스트 아래)에 추가:

```swift
    @Test("부위는 고정 순서로 한 줄에 잇고, 태그가 없으면 비운다")
    func bodyPartsText() throws {
        let context = try GrassFixture.makeContext()
        let tagged = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28, 7), totalSeconds: 600)
        tagged.toggle(.arms)
        tagged.toggle(.chest)
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 9, 28, 6), totalSeconds: 600)

        let rows = try #require(try sections(context).first).rows
        #expect(rows.map(\.bodyPartsText) == ["가슴 · 팔", nil])
    }
```

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFitWatchTests -destination "id=$WATCH" \
  test -only-testing:HaruchiFitWatchTests/RecordListBuilderTests
```

Expected: 컴파일 실패 — `value of type 'RecordListRow' has no member 'bodyPartsText'`

- [ ] **Step 3: 행 모델과 빌더에 부위를 더한다**

`RecordListRow.swift` — `caloriesText` 아래에 추가:

```swift
    /// `가슴 · 팔`. 칩이 아니라 한 줄 텍스트다 — 구간 칩과 한 줄에 두면 좁은 폰에서 kcal 을 밀어낸다.
    /// 태그가 없으면 nil (태깅을 유도하는 문구를 두지 않는다 — 스펙 04).
    let bodyPartsText: String?
```

`RecordListBuilder.swift` — `row(for:formatter:)` 의 반환을 바꾼다:

```swift
        let parts = record.bodyParts
        return RecordListRow(id: record.persistentModelID,
                             record: record,
                             dateTitle: formatter.string(from: record.startedAt),
                             chips: segmentChips(for: record),
                             caloriesText: calories,
                             bodyPartsText: parts.isEmpty ? nil : parts.map(\.title).joined(separator: " · "))
```

- [ ] **Step 4: 테스트가 통과하는지 확인한다**

Step 2 명령을 다시 실행한다. Expected: `RecordListBuilderTests` 9개 통과.

- [ ] **Step 5: 행 컴포넌트에 부위 줄을 그린다**

`RecordRow.swift` — 칩 `HStack` 의 `if` 블록 바로 아래(같은 `VStack` 안)에 추가하고, 파일 doc 주석의 *"날짜와 구간 칩"* 을 *"날짜와 구간 칩, 부위"* 로 고친다:

```swift
                if let parts = row.bodyPartsText {
                    Text(parts)
                        .font(.caption)
                        .foregroundStyle(HaruchiPalette.dim)
                        .lineLimit(1)
                }
```

- [ ] **Step 6: iOS 빌드**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFit -destination "id=$IOS" build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 7: 커밋**

```bash
git add Apps/HaruchiFit/Shared/Models/RecordListRow.swift \
        Apps/HaruchiFit/Shared/Models/RecordListBuilder.swift \
        Apps/HaruchiFit/watchosTests/Models/RecordListBuilderTests.swift \
        Apps/HaruchiFit/iOSApp/Features/Records/Components/RecordRow.swift
git commit -m "✨ 하루치 기록 목록 행에 태그한 부위를 보여준다"
```

---

## Task 4: 기록 상세 하프 시트와 목록 탭 진입

**Files:**
- Modify: `Apps/HaruchiFit/iOSApp/AppAlert.swift`
- Create: `Apps/HaruchiFit/iOSApp/Features/Records/Detail/RecordDetailViewModel.swift`
- Create: `Apps/HaruchiFit/iOSApp/Features/Records/Detail/Components/SegmentTimelineBar.swift`
- Create: `Apps/HaruchiFit/iOSApp/Features/Records/Detail/Components/BodyPartChips.swift`
- Create: `Apps/HaruchiFit/iOSApp/Features/Records/Detail/RecordDetailView.swift`
- Modify: `Apps/HaruchiFit/iOSApp/Features/Records/RecordsView.swift`

**Interfaces:**
- Consumes: Task 1 의 `WorkoutRecord.bodyParts` · `.toggle(_:)` · `.setMemo(_:)`, Task 2 의 `RecordDetailBuilder.summary(for:now:calendar:locale:)` ·
  `RecordDetailSummary` · `.Span`, 기존 `RecordsViewModel.delete(_:in:) -> Bool` · `.rebuild(from:)`, 환경 객체 `AppAlertCenter.report(_:)`
- Produces:
  - `AppAlert.editFailed`
  - `@MainActor final class RecordDetailViewModel: ObservableObject { let summary: RecordDetailSummary; @Published private(set) var bodyParts: [BodyPart]; @Published var memoDraft: String; func toggle(_: BodyPart) -> Bool; func commitMemo() -> Bool }`
  - `struct RecordDetailView: View { init(record: WorkoutRecord, context: ModelContext, onDelete: @escaping () -> Void) }` — #7·#8 이 같은 시트를 띄운다

UI 배선이라 단위 테스트가 없다 (iOS 테스트 타깃 없음). 규칙은 Task 1·2 가 검증했고, 여기는 빌드와 Step 8 시뮬레이터 확인이 검증이다.
부위 저장과 메모 초안 갱신은 분리한다. 메모에 포커스가 남은 채 부위 칩을 눌러도 입력 중인 초안이 덮어써지면 안 된다.

- [ ] **Step 1: 편집 실패 알림을 더한다**

`AppAlert.swift` — 케이스와 두 `switch` 에 하나씩 더한다:

```swift
    case editFailed
```

```swift
        case .editFailed: "변경 내용을 저장하지 못했어요"
```

```swift
        case .editFailed: "잠시 후 다시 시도해 주세요."
```

타입 doc 주석에 한 줄 덧붙인다: *"`editFailed` 는 기록 상세 시트가 직접 띄운다 — 시트가 떠 있는 동안 앱 루트 알림은 표시되지 않는다."*

- [ ] **Step 2: 뷰모델을 만든다**

`Apps/HaruchiFit/iOSApp/Features/Records/Detail/RecordDetailViewModel.swift`:

```swift
import Combine
import Foundation
import SwiftData

/// 기록 상세의 배선. **표시 규칙은 `RecordDetailBuilder`, 편집 규칙은 `WorkoutRecord+Annotations` 에 있다** —
/// 이 자리는 iOS 테스트 타깃이 없어 유닛 테스트가 닿지 않는다 (`RecordsViewModel` 과 같은 이유).
///
/// 요약은 시트를 열 때 한 번 만든다. 시트가 떠 있는 동안 바뀌는 건 부위·메모뿐이다.
@MainActor
final class RecordDetailViewModel: ObservableObject {
    let summary: RecordDetailSummary
    @Published private(set) var bodyParts: [BodyPart]
    @Published var memoDraft: String

    private let record: WorkoutRecord
    private let context: ModelContext

    /// `context` 는 `record` 가 속한 컨텍스트여야 한다 — 목록의 `@Query` 결과라 화면의 main context 다.
    init(record: WorkoutRecord, context: ModelContext, calendar: Calendar = .current) {
        self.record = record
        self.context = context
        summary = RecordDetailBuilder.summary(for: record, now: Date(), calendar: calendar)
        bodyParts = record.bodyParts
        memoDraft = record.memo ?? ""
    }

    /// 탭 즉시 저장한다 (스펙 04 "저장 자동"). 실패하면 되돌리고 false.
    func toggle(_ part: BodyPart) -> Bool {
        record.toggle(part)
        return persist(normalizeMemoDraft: false)
    }

    /// 포커스가 빠지거나 시트가 닫힐 때 부른다 (플랜 결정 D6). 바뀐 게 없으면 저장하지 않는다.
    func commitMemo() -> Bool {
        let before = record.memo
        record.setMemo(memoDraft)
        guard record.memo != before else {
            memoDraft = record.memo ?? ""
            return true
        }
        return persist(normalizeMemoDraft: true)
    }

    private func persist(normalizeMemoDraft: Bool) -> Bool {
        defer {
            // 부위 저장은 입력 중인 메모 초안을 건드리지 않는다.
            // 메모 저장 성공 때만 정규화하고, 실패 때는 초안을 남겨 다시 저장할 수 있게 한다.
            bodyParts = record.bodyParts
        }
        do {
            try context.save()
            if normalizeMemoDraft { memoDraft = record.memo ?? "" }
            return true
        } catch {
            context.rollback()
            print("[HaruchiFit] 기록 편집 저장 실패 — \(error)")
            return false
        }
    }
}
```

- [ ] **Step 3: 운동 구성 바를 만든다**

`Apps/HaruchiFit/iOSApp/Features/Records/Detail/Components/SegmentTimelineBar.swift`:

```swift
import SwiftUI

/// 운동 구성을 **길이 비율대로** 그리는 가로 바 (제품 스펙 04).
///
/// 워치 `SegmentBar` 의 iOS 복제본이다. 앱의 `Shared/` 는 UI 자리가 아니고, Kit 으로 올리면 Kit 이
/// 근력/유산소라는 도메인을 알게 된다. 두 바는 색 토큰부터 다르다 (`BrandColor` / `HaruchiPalette`).
/// 폭 계산 규칙은 그쪽과 같다.
struct SegmentTimelineBar: View {
    let spans: [RecordDetailSummary.Span]
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                ForEach(Array(widths(in: proxy.size.width).enumerated()), id: \.offset) { index, width in
                    Rectangle()
                        .fill(spans[index].kind == .strength ? HaruchiPalette.accent : HaruchiPalette.cardio)
                        .frame(width: width)
                }
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
    }

    /// **누적 위치를 먼저 반올림하고 그 차이를 폭으로 쓴다.** 칸마다 따로 반올림하면 합이 전체 폭과 어긋난다.
    private func widths(in totalWidth: CGFloat) -> [CGFloat] {
        let total = spans.reduce(0) { $0 + $1.seconds }
        guard total > 0 else { return [] }

        var widths: [CGFloat] = []
        var elapsed = 0
        var previousEdge: CGFloat = 0
        for span in spans {
            elapsed += span.seconds
            let edge = (CGFloat(elapsed) / CGFloat(total) * totalWidth).rounded()
            widths.append(edge - previousEdge)
            previousEdge = edge
        }
        return widths
    }
}
```

- [ ] **Step 4: 부위 칩을 만든다**

`Apps/HaruchiFit/iOSApp/Features/Records/Detail/Components/BodyPartChips.swift`:

```swift
import SwiftUI

/// 부위 6개 토글 칩 (D1 — 멀티 선택). 선택 상태는 위에서 받고, 탭은 위로 올린다.
/// 3열 × 2행 — 6개를 한 줄에 두면 좁은 폰에서 `어깨`·`하체` 가 잘린다.
struct BodyPartChips: View {
    let selected: [BodyPart]
    let onToggle: (BodyPart) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(BodyPart.allCases, id: \.self) { part in
                let isOn = selected.contains(part)
                Button { onToggle(part) } label: {
                    Text(part.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(isOn ? HaruchiPalette.bg : HaruchiPalette.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isOn ? HaruchiPalette.accent : HaruchiPalette.surface2, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}
```

- [ ] **Step 5: 시트를 만든다**

`Apps/HaruchiFit/iOSApp/Features/Records/Detail/RecordDetailView.swift`:

```swift
import SwiftData
import SwiftUI

/// 기록 상세 하프 시트 (제품 스펙 04). 부위·메모는 고치는 즉시 저장한다 — 저장 버튼이 없다.
/// `편집`·공유는 이번 범위가 아니다 (#5 플랜 결정 D1·D2).
struct RecordDetailView: View {
    @StateObject private var viewModel: RecordDetailViewModel
    @FocusState private var memoFocused: Bool
    @State private var detent: PresentationDetent = .medium
    @State private var confirmingDelete = false
    @State private var failure: AppAlert?
    private let onDelete: () -> Void

    /// `onDelete` 는 **지우지 말고 시트를 내리게만** 한다 — 떠 있는 시트가 지워진 모델을 읽으면 크래시한다.
    init(record: WorkoutRecord, context: ModelContext, onDelete: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: RecordDetailViewModel(record: record, context: context))
        self.onDelete = onDelete
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                stats
                if !viewModel.summary.spans.isEmpty { composition }
                Divider().overlay(HaruchiPalette.line)
                parts
                memo
                deleteButton
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationDragIndicator(.visible)
        .presentationBackground(HaruchiPalette.bg)
        .onChange(of: memoFocused) { _, focused in
            // 키보드에 메모가 가리지 않게 올린다. 포커스가 빠지면 저장한다 (결정 D6)
            if focused { detent = .large } else { commitMemo() }
        }
        // `완료` 없이 쓸어내려도 쓴 내용이 남는다. 실패해도 알릴 화면이 이미 없다 — 로그만 남는다
        .onDisappear { _ = viewModel.commitMemo() }
        .confirmationDialog("이 기록을 삭제할까요?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive) { onDelete() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("건강 앱의 운동 기록은 그대로 남아요.")
        }
        // 앱 루트 알림은 시트가 떠 있는 동안 표시되지 않는다 (결정 D8)
        .alert(failure?.title ?? "",
               isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } }),
               presenting: failure)
        { _ in
            Button("확인", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.summary.dateTitle)
                .font(.title3.weight(.bold))
                .foregroundStyle(HaruchiPalette.text)
            Text(viewModel.summary.timeRangeTitle)
                .font(.subheadline)
                .foregroundStyle(HaruchiPalette.dim)
        }
    }

    private var stats: some View {
        HStack(spacing: 8) {
            statTile(value: viewModel.summary.durationText, caption: "총 시간", color: HaruchiPalette.text)
            statTile(value: viewModel.summary.caloriesText, caption: "kcal", color: HaruchiPalette.text)
            statTile(value: viewModel.summary.heartRateText, caption: "평균 심박", color: HaruchiPalette.hr)
        }
    }

    private func statTile(value: String, caption: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(color)
            Text(caption)
                .font(.caption)
                .foregroundStyle(HaruchiPalette.dim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(HaruchiPalette.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private var composition: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("운동 구성")
            SegmentTimelineBar(spans: viewModel.summary.spans)
            if let text = viewModel.summary.compositionText {
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(HaruchiPalette.dim)
            }
        }
    }

    private var parts: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("부위")
            BodyPartChips(selected: viewModel.bodyParts) { part in
                if !viewModel.toggle(part) { failure = .editFailed }
            }
        }
    }

    private var memo: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionTitle("메모")
                Spacer()
                if memoFocused {
                    Button("완료") { memoFocused = false }
                        .font(.subheadline.weight(.semibold))
                        .tint(HaruchiPalette.accent)
                }
            }
            TextField("메모 추가하기…", text: $viewModel.memoDraft, axis: .vertical)
                .lineLimit(3 ... 8)
                .focused($memoFocused)
                .foregroundStyle(HaruchiPalette.text)
                .padding(12)
                .background(HaruchiPalette.surface, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) { confirmingDelete = true } label: {
            Text("삭제").frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(HaruchiPalette.hr)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(HaruchiPalette.dim)
    }

    private func commitMemo() {
        if !viewModel.commitMemo() { failure = .editFailed }
    }
}
```

- [ ] **Step 6: 기록 탭에 행 탭과 시트를 붙인다**

`RecordsView.swift`

doc 주석 둘째 줄 *"행 탭 → 기록 상세는 Phase 3 #5 가 붙인다."* 를 *"행 탭 → 기록 상세 하프 시트 (스펙 04)."* 로 바꾼다.

프로퍼티 `pendingDelete` 아래에 추가:

```swift
    @State private var selected: WorkoutRecord?
    /// 시트에서 삭제를 고른 기록. 시트가 **완전히 내려간 뒤** `finishDetail()` 이 지운다.
    @State private var deleteAfterDismiss: WorkoutRecord?
```

`.onChange(of: scenePhase)` 줄 아래(같은 체인)에 추가:

```swift
                .sheet(item: $selected, onDismiss: finishDetail) { record in
                    RecordDetailView(record: record, context: modelContext) {
                        deleteAfterDismiss = record
                        selected = nil
                    }
                }
```

`ForEach(section.rows)` 안의 `RecordRow(row: row)` 를 버튼으로 감싼다 (뒤따르는 `.listRowBackground`·`.swipeActions` 는 버튼에 그대로 붙는다):

```swift
                            Button { selected = row.record } label: {
                                RecordRow(row: row)
                            }
```

`confirmDelete()` 아래에 추가:

```swift
    /// 시트가 내려간 뒤에 부른다.
    /// - 삭제를 골랐으면 여기서 지운다 — 떠 있는 시트가 지워진 모델을 읽으면 크래시한다.
    ///   목록은 `onChange(of: records)` 가 다시 만든다. **여기서 `rebuild` 하지 않는다** — 아직 갱신 전인
    ///   `records` 에 지운 모델이 남아 있다.
    /// - 아니면 목록을 다시 만든다. 시트에서 고친 부위는 `onChange(of: records)` 에 안 걸린다
    ///   (배열 비교가 모델 동일성이라 속성 변경을 못 본다).
    private func finishDetail() {
        if let record = deleteAfterDismiss {
            deleteAfterDismiss = nil
            if !viewModel.delete(record, in: modelContext) {
                alerts.report(.deleteFailed)
            }
            return
        }
        viewModel.rebuild(from: records)
    }
```

- [ ] **Step 7: iOS 빌드 · 전체 워치 테스트 · lint · format**

```bash
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFit -destination "id=$IOS" build
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFitWatchTests -destination "id=$WATCH" test
make lint
make format
git diff --check
```

Expected: `** BUILD SUCCEEDED **` · `** TEST SUCCEEDED **` · 새 경고·위반 0. `make format` 이 걸리면 `make fix` 로 고치고 diff 를 다시 본다.

- [ ] **Step 8: 시뮬레이터 확인**

**먼저 마이그레이션.** 기존 데이터가 있는 시뮬레이터(#4 확인 때 쓴 기기)에 **지우지 않고** 덮어 설치해 첫 실행이
크래시 없이 목록을 띄우는지 본다. 데이터가 없으면 `main` 빌드를 먼저 설치하고 건강 앱에 근력 운동 1건을 넣어 import 시킨 뒤 덮어 설치한다.

그다음 건강 앱에 근력 1건(이번 주, 칼로리 입력)·달리기 1건(심박 없이)을 수동 추가하고 import 시킨 뒤:

- 행 탭 → 시트가 `.medium` 으로 열리고 그랩 핸들이 보이는지. 끌어올리면 `.large`
- 헤더 날짜·`오전/오후/저녁 h:mm – h:mm`, 요약 3칸, 달리기 기록의 심박 칸이 `–` 인지
- 운동 구성 바 색(근력 오렌지 · 유산소 파랑)과 `근력 N분` 문구
- **유산소 기록에서도 부위 섹션이 보이는지** (스펙 04)
- 부위 2개 탭 → 시트 닫기 → **목록 행에 `가슴 · 팔` 이 바로 보이는지** (Review Focus 2) → 앱 재실행 후에도 남는지
- 메모에 포커스 → 시트가 `.large` 로 올라가고 `완료` 가 보이는지. 쓰고 `완료` 없이 쓸어내린 뒤 다시 열면 남아 있는지 (Review Focus 4)
- 메모를 입력하는 중에 부위 칩을 탭해도 초안이 사라지지 않고, `완료` 후 다시 열면 태그·메모가 함께 남는지
- 부위 6개 선택과 접근성 큰 글자 크기에서 상세 칩·요약·목록 부위 줄이 읽히고 조작 가능한지
- 메모를 공백만 남기고 닫으면 다시 열었을 때 플레이스홀더가 보이는지
- 시트의 `삭제` → `취소` 시 시트가 그대로인지, `삭제` 확정 시 **시트가 내려간 뒤 행이 사라지고 크래시가 없는지** (Review Focus 3), 홈 잔디 칸도 비는지
- 행 스와이프 삭제가 예전처럼 동작하는지 (버튼으로 감싼 뒤 회귀)

`editFailed` 는 시뮬레이터에서 실패를 재현할 수단이 없다 — 코드 리뷰로 확인한다 (목록 플랜의 알림들과 같다).
워치 재전송 시 이어받기(Review Focus 1)는 Task 1 테스트가 검증하고, 실기기 항목으로 TODO 에 남긴다.

- [ ] **Step 9: 커밋**

```bash
git add Apps/HaruchiFit/iOSApp/AppAlert.swift \
        Apps/HaruchiFit/iOSApp/Features/Records/
git commit -m "✨ 하루치 기록 상세 하프 시트에서 부위·메모를 고친다"
```

---

## Task 5: 문서 갱신 · PR

**Files:**
- Modify: `Apps/HaruchiFit/CLAUDE.md`
- Modify: `Apps/HaruchiFit/docs/specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md`
- Modify: `TODO.md`

- [ ] **Step 1: 앱 `CLAUDE.md`**
  - Project overview 의 *"기록 탭은 주 단위 목록이다"* 에 *"행을 탭하면 부위·메모를 고치는 상세 시트가 열린다"* 를 더한다
  - Architecture 트리의 `Features/Records/` 줄 아래에 `Features/Records/Detail/  기록 상세 하프 시트 · 부위 태깅 · 메모` 를 더한다
  - "데이터" 절 매칭 키 항목에 *"워치 재전송은 레코드를 갈아끼우므로 `adoptAnnotations(from:)` 로 부위·메모를 넘겨받는다"* 를 더한다

- [ ] **Step 2: 로드맵**
  - Phase 3 표의 #5 행을 취소선 + `**완료 — PR #N.**` 으로. 비고에 *"`편집` 은 #11 수동 기록 폼과 함께 정한다, 공유 `↑` 는 #6"* 을 적는다
  - #6 행 비고에 *"시트 헤더 우측과 액션 줄에 자리를 비워 뒀다"* 를 더한다
  - 의존 관계 그림의 `04 상세` 에 취소선
  - #11 행 비고에 *"기록 상세 `편집` 의 범위를 이 폼으로 정한다 (#5 플랜 D1)"* 를 더한다

- [ ] **Step 3: `TODO.md`** (루트 규약 — 같은 커밋에서)
  - 하루치 예정사항 표 #5 행을 취소선 + `**완료** ([PR #N](…))`
  - #6 행을 `**다음 코드 작업**` 으로
  - 본문 *"다음 코드는 Phase 3 #5 기록 상세다"* 를 #6 공유로 고친다
  - 하루치 "집 맥북에서 할 것" 에 항목을 더한다:
    `- [ ] **기록 상세 실기기 확인** — 워치에서 저장한 기록에 부위·메모를 붙인 뒤 워치가 같은 기록을 다시 보내도 남는지(재배달은 드물다 — 확인 수단이 없으면 코드 리뷰로 갈음), 한국어 기기에서 시간대 이름(`저녁`·`밤`)이 스펙대로 찍히는지`

- [ ] **Step 4: 사용자 검토 후 커밋 · PR**

```bash
git add Apps/HaruchiFit/CLAUDE.md \
        Apps/HaruchiFit/docs/specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md \
        Apps/HaruchiFit/docs/plans/ios/2026/2026-10-06-record-detail.md \
        TODO.md
git commit -m "📝 하루치 기록 상세 완료를 로드맵·TODO 에 반영한다"
git push -u origin feat/haruchi-record-detail
gh pr create --title "✨ 하루치 기록 상세 — 부위 태깅 · 메모 하프 시트" \
  --body "기록 행을 탭하면 하프 시트에서 운동 요약·구성을 보고 부위 6개와 메모를 자동 저장합니다. 워치 재전송에도 부위·메모를 보존합니다. 검증 결과는 이 플랜의 완료 기준 체크리스트에 기록합니다. 공유는 #6, 시각·유형 편집은 #11에서 다룹니다."
```

PR 번호가 나오면 Step 2·3 의 `#N` 을 실제 번호로 채워 한 번 더 커밋·푸시한다.
머지와 워크트리 정리는 이 플랜의 구현 완료 후 사용자 검토·승인을 받은 다음 진행한다.
실기기·Xcode 확인이 남으면 워크트리를 유지한다 (루트 `CLAUDE.md`).
최종 승인 뒤 일반 merge commit으로 머지하고, 워크트리 제거 시 해당 DerivedData도 공통 규약대로 정리한다.

## 완료 기준

- `WorkoutRecordAnnotationTests` 5개 · `RecordDetailBuilderTests` 9개 · `RecordListBuilderTests` 9개 포함 워치 테스트 전체 통과
- iOS 빌드 · `make lint` · `make format` · `git diff --check` 통과
- 시뮬레이터에서 Task 4 Step 8 항목 전부 확인 (마이그레이션 포함)
- 스펙 04 중 `편집`·공유가 각각 #11·#6 으로 넘어갔다는 것이 로드맵·TODO 에 적혀 있다
