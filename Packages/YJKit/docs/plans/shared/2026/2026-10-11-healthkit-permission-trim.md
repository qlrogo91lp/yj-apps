# HealthKit 권한 시트 정리 — 구현 플랜

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 워치에서 뜨는 건강 권한 시트의 요청 항목을 줄인다. Ralli·하루치 8항목 → 4항목, 골프 12항목 → 6항목.
**기존 동작(운동 저장·심박·칼로리·거리·걸음 수)은 하나도 바뀌지 않아야 한다** — 이게 이 작업의 통과 조건이다 (§기존 동작에 미치는 영향). 하루치 워치는 권한을 묻는 시점도 골프·Ralli 처럼 **운동 시작 버튼**으로 옮긴다.

**Architecture:** 시트는 시스템이 그린다. 우리가 정하는 건 `requestAuthorization(toShare:read:)` 에 넘기는
**목록**뿐이고, 목록의 항목 하나가 시트의 항목 하나가 된다. 지금은 같은 데이터를 쓰기·읽기 양쪽으로 묻는다. 실제로 쓰기가
필요한 건 운동 하나뿐이라 그 중복을 걷어낸다. 목록은 YJKit `WorkoutSessionService` 가 소유하므로 **세 앱이 한꺼번에 바뀐다.**

**Tech Stack:** Swift 6 · HealthKit · swift-testing · watchOS 10

**발단:** 하루치 01 온보딩 브레인스토밍 (2026-10-09~11) 중 "권한 시트가 너무 길다"는 문제가 나와 먼저 떼어 냈다.
온보딩 스펙은 이 작업 뒤에 쓴다.

---

## 배경 — 지금 무엇을 묻고 있나

| 앱 | 쪽 | 호출 위치 | 시점 | 쓰기 | 읽기 | 항목 수 |
|---|---|---|---|---|---|---|
| GolfCounter | 워치 | `RoundSessionView.swift:101` | 라운드 시작 | 6 | 6 | 12 |
| Ralli | 워치 | `WorkoutSessionViewModel.swift:187` | 매치 시작 | 4 | 4 | 8 |
| HaruchiFit | 워치 | `WatchApp.swift:14` (`.task`) | **앱 켜자마자** | 4 | 4 | 8 |
| Ralli | iOS | `WorkoutDeletionService` | 기록 삭제 시 | 운동 1 | — | 1 |
| HaruchiFit | iOS | `WorkoutSyncCoordinator.swift:35` | 포그라운드마다 | — | 4 | 4 |

- 워치 세 줄은 모두 `WorkoutSessionService.requestAuthorization()` 이다. 기본 4종(활동 칼로리 · 휴식 칼로리 · 심박 · 운동)을
  **쓰기·읽기 양쪽에** 넣고, 골프는 `additionalReadTypes`(걷기 거리 · 걸음 수)를 양쪽에 더한다.
- 쓰기에 칼로리·심박까지 넣은 근거는 커밋 `8db80033` 의 주석("수집하는 타입은 `finishWorkout()` 이 저장하려 하므로
  share 권한도 필요하다") 하나다. **증상을 보고 고친 게 아니라 예방 조치였다** — 골프 [counter-core 플랜](../../../../../../Apps/GolfCounter/docs/plans/watch/2026/2026-08-04-counter-core.md)
  81행이 "거리·걸음수가 Health 에 조용히 저장 안 **될 수 있는 위험**"이라고 적었고, 커밋은 단위 테스트만 더했다.
  실제로 저장이 안 되는지는 그때도 지금도 확인된 적이 없다 → 골프 거리·걸음 수는 **골프 앱 다음 업데이트를 출시하기 전에** 실기기로 확인한다 (§실기기 확인).
- 권한(허용/거부 기록)은 **폰 앱과 워치 앱이 하나로 묶여** 있다. 건강 앱 › 앱 목록에 앱이 하나만 나오고,
  Ralli #10 에서 폰 앱이 워치 앱이 저장한 운동을 지울 수 있었다. 요청은 기기마다 따로 하지만 이미 결정된 항목은 어느 쪽에서도 다시 뜨지 않는다.

### 스파이크 결과 (2026-10-11, 시뮬레이터, watchOS 27.0)

`spike/healthkit-share-types` 에서 Ralli 워치로 확인했다. 코드는 버렸다.

| | 대조군 (쓰기 4종) | 스파이크 (쓰기 = 운동만) |
|---|---|---|
| 시트 | 쓰기 4 + 읽기 3 | **쓰기 1 + 읽기 3** |
| 실행 시간 | 4분 23초 | 6분 35초 |
| `finishWorkout()` | 성공 | **성공** |
| 평균 심박 | 59.7 | **60.2** |
| 휴식 칼로리 | 3.36 | **5.05** |
| 활동 칼로리 | 0 | 0 |

- **칼로리·심박 쓰기 권한 없이도 운동 저장 · 심박 · 휴식 칼로리가 나온다.**
- 활동 칼로리는 양쪽 다 0 이다. 시뮬레이터가 움직임을 흉내 내지 않는다 → 실기기에서 확인했다 — **22 kcal** (Task 0 · §실행 기록).
- 첫 스파이크 실행은 수십 초만 돌아 0/nil 이 나왔다. 짧게 돌리면 판정이 안 된다.
- **HealthKit 권한은 앱을 지웠다 다시 깔아도 시뮬레이터에 남는다.** 시트를 다시 보려면 `xcrun simctl erase` 가 필요했다.

### OS 27 의 새 단계 — "과거 데이터를 얼마나"

읽기 권한 시트에 **"최근 30일 / 전체 기록"** 선택이 새로 생겼다 (watchOS 27 시뮬레이터에서 확인).
워치 세 앱은 운동 중 실시간 값만 읽으므로 영향이 없다. **하루치 iOS import 에는 크게 걸린다** — 온보딩 스펙에서 다룬다 (§범위 밖).

---

## 권한 비교 — 지금과 정리 후

### 1. 워치 요청 항목 (데이터 × 방향)

● = 요청함 · — = 요청 안 함 · **굵게** = 이번에 빠지는 항목. 세 앱 모두 `WorkoutSessionService` 한 곳에서 나온다.

| 데이터 | 방향 | Ralli 지금 | Ralli 후 | 하루치 지금 | 하루치 후 | 골프 지금 | 골프 후 |
|---|---|---|---|---|---|---|---|
| 운동 | 쓰기 | ● | ● | ● | ● | ● | ● |
| 운동 | 읽기 | ● | **—** | ● | **—** | ● | **—** |
| 활동 칼로리 | 쓰기 | ● | **—** | ● | **—** | ● | **—** |
| 활동 칼로리 | 읽기 | ● | ● | ● | ● | ● | ● |
| 휴식 칼로리 | 쓰기 | ● | **—** | ● | **—** | ● | **—** |
| 휴식 칼로리 | 읽기 | ● | ● | ● | ● | ● | ● |
| 심박 | 쓰기 | ● | **—** | ● | **—** | ● | **—** |
| 심박 | 읽기 | ● | ● | ● | ● | ● | ● |
| 걷기·달리기 거리 | 쓰기 | — | — | — | — | ● | **—** |
| 걷기·달리기 거리 | 읽기 | — | — | — | — | ● | ● |
| 걸음 수 | 쓰기 | — | — | — | — | ● | **—** |
| 걸음 수 | 읽기 | — | — | — | — | ● | ● |
| **쓰기 합계** | | 4 | **1** | 4 | **1** | 6 | **1** |
| **읽기 합계** | | 4 | **3** | 4 | **3** | 6 | **5** |
| **전체** | | 8 | **4** | 8 | **4** | 12 | **6** |

### 2. 시트 페이지 단위 (watchOS 27 시뮬레이터에서 본 순서)

쓰기와 읽기는 **별개 페이지**다. 둘 다 필요하므로 **페이지 수는 줄지 않고** 각 페이지의 항목 수만 준다.

| 페이지 | Ralli 지금 → 후 | 하루치 지금 → 후 | 골프 지금 → 후 | 우리가 바꿀 수 있나 |
|---|---|---|---|---|
| 건강 접근 (`검토`) | 그대로 | 그대로 | 그대로 | 불가 (시스템) |
| 읽기 범위 — 최근 30일 / 전체 | 그대로 | 그대로 | 그대로 | 불가 (OS 27 신규) |
| 쓰기 접근 허용 | 4 → **1** | 4 → **1** | 6 → **1** | 항목 수만 |
| 읽기 접근 허용 | 4 → **3** | 4 → **3** | 6 → **5** | 항목 수만 |

- 스파이크 빌드에서 읽기 범위 페이지가 "건강 주제를 **3개** 선택했습니다" 라고 표시했다 — 읽기 3항목이 그대로 반영된다.
- 각 페이지 상단은 `아래 요청된 모든 데이터` 토글 하나다. 그 아래 개별 항목이 토글인지 목록인지는 스크롤한 화면을 못 봐서 **미확인**이다.
- watchOS 26 이하의 시트 모양은 이번에 확인하지 않았다.

### 3. iOS 요청과, 워치를 먼저 쓴 사용자에게 뜨는 것

iOS 코드는 이번에 바꾸지 않는다. 다만 권한이 폰·워치에 하나로 묶여 있어, **워치가 묻지 않게 된 항목은 iOS 가 처음 묻는 항목이 된다.**

| 앱 | iOS 가 요청하는 것 | 워치에서 먼저 허용한 사용자 — 지금 | 워치에서 먼저 허용한 사용자 — 후 |
|---|---|---|---|
| GolfCounter | 없음 | — | — |
| Ralli | 운동 쓰기 (기록 삭제 시) | 시트 안 뜸 | 시트 안 뜸 (워치가 운동 쓰기를 계속 묻는다) |
| 하루치 | 운동 · 활동 칼로리 · 휴식 칼로리 · 심박 **읽기** | 시트 안 뜸 — 4항목을 워치에서 이미 결정 | **운동 읽기 1항목 시트가 뜬다** (+ OS 27 읽기 범위 페이지) |

---

## 기존 동작에 미치는 영향

권한을 빼도 기존 동작이 그대로인지가 이 작업의 통과 조건이다. 기능마다 **어느 권한에 기대는지**와 **어디까지 확인됐는지**를 적는다.

✅ 확인 (시뮬레이터 또는 실기기 — 근거 칸에 적는다) · ⏳ 실기기 확인 대기 · 🔧 코드를 바꿔 대응 · ➖ 권한 목록과 무관

| # | 기능 | 쓰는 앱 | 기대는 권한 | 그 권한은 | 상태 | 근거 · 남은 일 |
|---|---|---|---|---|---|---|
| 1 | 운동을 건강 앱에 저장 (`finishWorkout()`) | 3앱 | 운동 쓰기 | 유지 | ✅ | 쓰기 = 운동 1종으로 저장 성공 |
| 2 | 저장된 운동의 `healthKitUUID` 받기 (Ralli 삭제 연동 · 하루치 중복 방지 키) | Ralli · 하루치 | `finishWorkout()` 반환값 | 유지 | ✅ | uuid 가 반환됐다. 운동 읽기 없이도 |
| 3 | 운동 중 심박 표시 · 평균 심박 | 3앱 | 심박 읽기 | 유지 (쓰기만 빠짐) | ✅ | 평균 60.2 (대조군 59.7) |
| 4 | 휴식 칼로리 → 총 칼로리 | 3앱 | 휴식 칼로리 읽기 | 유지 (쓰기만 빠짐) | ✅ | 5.05 (대조군 3.36, 실행 시간 차이) |
| 5 | **활동 칼로리** (화면 · 요약 · 폰 기록) | 3앱 | 활동 칼로리 읽기 | 유지 (쓰기만 빠짐) | ✅ 실기기 | Ralli, 쓰기 3종을 끈 채 6분 10초 — 활동 22 kcal. Ralli 앱 기록도 22 kcal · 83 BPM 으로 같다 |
| 6 | **피트니스 앱** 운동 상세의 kcal · 심박 그래프 | 3앱 | 건강 저장소에 샘플이 남는가 | 쓰기가 빠짐 | ✅ 실기기 | 피트니스 앱 운동 상세 — 활동 22 kcal · 총 32 kcal · 평균 83 BPM · 심박 그래프 표시 |
| 7 | **건강 앱**에 활동·휴식 에너지 샘플이 남는가 | 3앱 | 위와 같음 | 쓰기가 빠짐 | ✅ 간접 | 6 의 kcal · 심박 그래프가 저장소 샘플에서 나온다. 건강 앱 데이터 보기와 샘플 출처는 따로 보지 않았다 |
| 8 | **거리 · 걸음 수** (`WorkoutResult` → `GolfRound`) | 골프 | 거리·걸음 읽기 | 유지 (쓰기만 빠짐) | ⏳ | 시뮬레이터는 0. `8db80033` 이 걱정한 바로 그 항목이다. **골프 앱 다음 업데이트 출시 전에 확인한다** (2026-10-11 결정) |
| 9 | 하루치 **버리기** — 건강 앱에서 운동 삭제 | 하루치 | 지금: 운동 읽기(조회) + 쓰기(삭제) | **읽기가 빠짐** | 🔧 ⏳ | Task 2 가 조회 없는 `deleteObjects` 로 바꾼다. 실기기에서 삭제 확인 |
| 10 | Ralli 기록 삭제 → 건강 앱 운동 삭제 | Ralli iOS | 운동 쓰기 (iOS 가 따로 요청) | 유지 | ➖ | 코드·권한 모두 그대로 |
| 11 | 하루치 **import** (다른 앱 운동을 잔디로) | 하루치 iOS | 운동·칼로리·심박 읽기 (iOS 가 요청) | 유지 | ➖ 동작 변화 있음 | 워치를 먼저 쓴 사용자는 지금 시트 없이 import 되지만, 후에는 iOS 에서 운동 읽기 1항목을 허용해야 한다 (§권한 비교 3) |
| 12 | 일시정지·재개 · 경과시간 · 구간 전환 · 컴플리케이션 | 3앱 | 없음 (세션 상태 · 앱 자체 시계) | — | ➖ | 권한 목록과 무관 |
| 13 | 워치 → 폰 기록 전송 (kcal · 심박 포함) | 3앱 | 없음 (WatchConnectivity) | — | ➖ | iOS 는 건강 앱에 칼로리를 쓰지 않는다 |
| 14 | `averageHeartRate(from:to:)` (심박 통계 쿼리) | — | 심박 읽기 | 유지 | ➖ | 호출부가 없다 |
| 15 | **이미 권한을 준 기존 사용자** | 3앱 | — | 회수되지 않음 | ➖ | 목록을 줄여도 준 권한은 남고 시트도 다시 안 뜬다. 오늘과 완전히 같은 상태로 돈다 |

**읽는 법**
- **위험은 5~9 에 몰려 있고, 새로 설치하는 사용자에게만 해당한다** (15).
- 5~8 은 같은 질문이다 — "빌더가 모은 샘플을 쓰기 권한 없이도 건강 저장소에 남기는가". Task 0 한 번으로 함께 답이 나온다.
- **2026-10-11 실기기 결과: 5~7 통과** (Ralli). 남은 것은 8 (골프 거리·걸음 수)과 9 (하루치 버리기)다.
- 11 은 고장이 아니라 **묻는 위치가 폰으로 옮겨지는 것**이다. 온보딩 전까지 하루치 iOS 는 앱을 켤 때 스스로 묻으므로 사용자가 놓칠 일은 없다.
- Task 0 에서 5~8 중 하나라도 실패하면 해당 데이터의 **쓰기를 되살린다** (아래 대안). 읽기 쪽 결정(운동 읽기 제거)은 9 만 통과하면 유지한다.

---

## 결정 사항

| 항목 | 결정 | 이유 |
|---|---|---|
| 워치 쓰기 목록 | **운동 1종** (`workoutType`). `additionalReadTypes` 도 쓰기에 넣지 않는다 | 스파이크에서 칼로리·심박 쓰기 없이 저장·측정이 됐다. 활동 칼로리는 Task 0 실기기에서 확정했다 (22 kcal) |
| 워치 읽기 목록 | 칼로리 2 · 심박 (+ `additionalReadTypes`). **운동 읽기를 뺀다** | 워치는 과거 운동을 조회하지 않는다. 유일한 사용처인 하루치 버리기를 `deleteObjects` 로 바꾼다 |
| 하루치 버리기 | `HKSampleQuery` → 삭제 대신 **`deleteObjects(of:predicate:)`** | 쓰기 권한 하나로 끝난다. Ralli `WorkoutDeletionService` 가 같은 API 로 실기기 확인을 마쳤다 (#10) |
| 하루치 워치 요청 시점 | 앱 실행 시 → **`운동 시작` 버튼** | 골프·Ralli 와 같다. 왜 묻는지 맥락이 생긴다 |
| 하루치 시작 순서 | **권한 결정을 기다린 뒤** 화면을 넘긴다 | 골프·Ralli 는 화면부터 넘기고 권한을 뒤에서 기다린다. 하루치는 구간 시계(`SegmentTracker`)가 시작 순간 돌기 시작해, 첫 실행 때 시트를 보는 시간이 첫 구간에 섞인다 |
| 두 번 누름 | 시작 중에는 버튼이 다시 먹지 않게 막는다 | 권한을 기다리는 동안 다시 누를 수 있다 (Ralli 시뮬레이터에서 두 번 눌러 모드 선택을 건너뛴 일이 있었다) |
| 설명 문구 | **하루치 워치 `NSHealthShareUsageDescription` 만** 고친다 | 지금 iOS 문구("잔디를 채우기 위해 읽습니다")를 그대로 복사해 워치가 하는 일(심박·칼로리 측정)과 안 맞는다. Ralli·골프 워치 문구는 이미 맞다 |
| 기존 사용자 | 아무것도 바뀌지 않는다 | 요청 목록을 줄여도 이미 준 권한은 회수되지 않는다. 시트도 다시 뜨지 않는다 |
| Ralli·하루치 iOS 요청 | 건드리지 않는다 | Ralli 는 삭제 시 운동 쓰기 1줄. 하루치는 온보딩 작업이 시점을 옮긴다 |

**Task 0 에서 활동 칼로리 쓰기가 필요하다고 나오면:** 쓰기 목록을 `[운동, 활동 칼로리, 휴식 칼로리]` 로 둔다
(심박 쓰기만 빠진다). 항목 수는 Ralli·하루치 6, 골프는 출시 전 실기기 확인의 거리·걸음 결과를 따른다 (거리·걸음 쓰기도 필요하면 8). 나머지 Task 는 그대로다.

---

## 범위 밖

- **하루치 iOS 의 권한 시점과 "최근 30일" 대응** — 01 온보딩 스펙이 다룬다.
  이 작업 뒤 하루치 iOS 는 **운동 읽기 1줄**을 새로 묻게 된다 (워치가 운동 읽기를 더 묻지 않으므로).
  온보딩 전까지는 지금처럼 앱을 켤 때 그 1줄이 뜬다. 온보딩 4장에서 묻는 게 자연스러워지는 변화라 의도된 결과다
- **하루치 import 의 앵커 리셋** — "최근 30일" 로 받은 앵커는 나중에 전체로 넓혀도 과거를 다시 주지 않는다는 보고가 있다. 온보딩 스펙에서 정한다
- Ralli 삭제 플랜 §후속의 **ReadMe 권한 표** — 별건으로 남긴다
- 권한 시트 직전의 설명 화면 — 하루치는 온보딩 4장이 그 역할이다

---

## Global Constraints

- **로컬 SPM 이라 Kit 만 먼저 머지할 수 없다.** YJKit 과 하루치 변경을 PR 하나로 묶는다
- `WorkoutSessionService` 의 공개 API(`requestAuthorization()` · `startWorkout()` 등)의 시그니처는 바꾸지 않는다. 목록 두 개만 바뀐다
- 워크아웃 동작 계약(루트 `CLAUDE.md`)을 건드리지 않는다
- 빌드·테스트는 워크스페이스 기준, 시뮬레이터는 UDID 로 지정한다
- 브랜치 `feat/healthkit-permission-trim` · 커밋 gitmoji

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
make kit-test KIT_DESTINATION="id=$IOS"
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
```

---

## File Structure

| 파일 | 변경 | 할 일 |
|---|---|---|
| `Packages/YJKit/Sources/WorkoutCore/WorkoutSessionService.swift` | 수정 | `typesToShare` = 운동 1종, `typesToRead` 에서 운동 제거. 주석을 실측 근거로 교체 |
| `Packages/YJKit/Tests/WorkoutCoreTests/WorkoutSessionServiceTests.swift` | 수정 | 목록 테스트 4개의 기대값 갱신 |
| `Apps/HaruchiFit/WatchApp/Services/HealthKitWorkoutRemover.swift` | 수정 | 조회 후 삭제 → `deleteObjects(of:predicate:)` |
| `Apps/HaruchiFit/WatchApp/WatchApp.swift` | 수정 | `.task { requestAuthorization }` 제거 |
| `Apps/HaruchiFit/WatchApp/Features/Workout/WorkoutViewModel.swift` | 수정 | `start()` 를 비동기로: 권한 → 세션 시작 → 화면 전환. 시작 중 재진입 차단. `requestAuthorization()` 제거 |
| `Apps/HaruchiFit/WatchApp/Features/Workout/Start/StartView.swift` | 수정 | 버튼이 `Task { await viewModel.start() }` 를 부르고, 시작 중이면 비활성 |
| `Apps/HaruchiFit/WatchApp/InfoPlist.xcstrings` | 수정 | `NSHealthShareUsageDescription` 한·영 문구를 워치 맥락으로 |
| `Apps/HaruchiFit/HaruchiFit.xcodeproj/project.pbxproj` | 수정 | 워치 타깃 빌드 설정의 같은 문구 (영문 원문). 카탈로그만 고치면 되돌아간다 |
| `TODO.md` | 수정 | YJKit 표에 이 항목 (플랜 커밋 때 추가, 완료 때 취소선) |

---

## Task 0: 실기기 확인 — 구현 전 관문 (사용자)

시뮬레이터로는 활동 칼로리를 못 본다. **출시된 앱 그대로** 확인할 수 있다 — 앱을 지우거나 스파이크 빌드를 깔 필요가 없다.
쓰기 토글을 끄는 것이 "권한 없음"과 같은 효과이고, 이미 결정된 항목이라 시트도 안 뜬다.

- [x] **Ralli** — 아이폰 건강 앱 › 프로필 › 앱 › Ralli › **쓰기**에서 활동 에너지 · 휴식 에너지 · 심박을 끈다 (운동은 켜 둠)
- [x] 워치에서 Ralli 매치를 **실제로 움직이며 5분 이상** 진행하고 종료·저장 — 6분 10초
- [x] 운동 중 화면의 활동 칼로리가 올라가는가 — 사용자 확인 "문제 없음"
- [x] 폰 Ralli 기록의 kcal 이 0 이 아닌가 — 22 kcal · 83 BPM (피트니스 앱과 같다)
- [x] 피트니스 앱 운동 상세에 kcal · 심박 그래프가 보이는가 — 활동 22 kcal · 총 32 kcal · 평균 83 BPM
- [ ] 건강 앱 › 활동 에너지 › 데이터 보기에 그 시간대 샘플이 있는가 (출처가 무엇으로 나오는지도 적는다) — 보지 않았다. 피트니스 앱 결과로 갈음
- GolfCounter 는 여기서 하지 않는다 — 골프 앱 다음 업데이트 때 본다 (§실기기 확인 · 2026-10-11 결정)
- [ ] 끝나면 끈 토글을 다시 켠다. 테스트 매치는 kcal 이 0 으로 남았으면 지운다

**판정:** 전부 정상 → 결정 사항 그대로. §기존 동작 5~8 중 실패한 데이터는 쓰기를 되살린다 → §결정 사항 아래의 대안 목록으로.
결과를 이 문서 끝 §실행 기록에 적는다.

---

## Task 1: YJKit — 요청 목록 줄이기

**Files:** Modify `Packages/YJKit/Sources/WorkoutCore/WorkoutSessionService.swift`, `Packages/YJKit/Tests/WorkoutCoreTests/WorkoutSessionServiceTests.swift`

- [ ] **Step 1: 테스트 기대값부터 바꾼다** (실패 확인)
  - `typesToShareOmitsAdditionalTypesByDefault` → 이름을 `typesToShareIsWorkoutOnly` 로. `count == 1`, `contains(workoutType())`
  - `typesToShareIncludesAdditionalTypes` → 이름을 `typesToShareExcludesAdditionalTypes` 로. 골프 설정에서도 `count == 1`, 걸음·거리 미포함
  - `typesToReadOmitsAdditionalTypesByDefault` → `count == 3`, `!contains(workoutType())` 추가
  - `typesToReadIncludesAdditionalTypes` → `count == 5`
- [ ] **Step 2:** `make kit-test` → 위 4개 실패 확인
- [ ] **Step 3: 구현**

```swift
/// **쓰기는 운동 하나뿐이다.** 심박·칼로리는 시스템이 저장하고 빌더는 읽기 권한만으로 통계를 받는다 —
/// 2026-10-11 시뮬레이터 스파이크에서 쓰기 4종 → 1종으로 줄여도 저장·심박·휴식 칼로리가 같았다
/// (`docs/plans/shared/2026/2026-10-11-healthkit-permission-trim.md`). 항목 하나가 시트의 토글 한 줄이다.
var typesToShare: Set<HKSampleType> {
    [HKObjectType.workoutType()]
}

/// 기본 3종 + configuration 이 지정한 추가 타입. **운동은 읽지 않는다** — 워치는 과거 운동을 조회하지 않는다.
var typesToRead: Set<HKObjectType> {
    var types: Set<HKObjectType> = [
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.basalEnergyBurned),
        HKQuantityType(.heartRate),
    ]
    for identifier in configuration.additionalReadTypes {
        types.insert(HKQuantityType(identifier))
    }
    return types
}
```

- [ ] **Step 4:** `make kit-test` 통과
- [ ] **Step 5:** 커밋 `♻️ refactor: 워치 건강 권한 요청을 쓰기 1종·읽기 3종으로 줄인다`

## Task 2: 하루치 버리기 — 조회 없이 삭제

**Files:** Modify `Apps/HaruchiFit/WatchApp/Services/HealthKitWorkoutRemover.swift`

운동 읽기를 뺐으므로 `HKSampleQuery` 가 빈 결과를 돌려줄 수 있다 (읽기 권한이 없으면 오류가 아니라 빈 결과).
`deleteObjects(of:predicate:)` 는 쓰기 권한 하나로 끝난다.

- [ ] **Step 1: 구현** — `remove(workoutWith:)` 본문을 아래로 바꾼다. 실패는 지금처럼 삼킨다 (기존 주석 유지)

```swift
func remove(workoutWith uuid: UUID) async {
    guard HKHealthStore.isHealthDataAvailable() else { return }
    // 조회를 끼우지 않는다 — 조회는 읽기 권한이 필요한데 워치는 운동을 읽지 않는다.
    // 쓰기 권한 하나로 끝나는 API 다 (Ralli `WorkoutDeletionService` 와 같다).
    _ = try? await store.deleteObjects(of: .workoutType(),
                                       predicate: HKQuery.predicateForObject(with: uuid))
}
```

- [ ] **Step 2:** `HaruchiFitWatchTests` 통과 (버리기는 `WorkoutRemovingSpy` 로 검증되므로 기존 테스트가 그대로 돈다)
- [ ] **Step 3:** 커밋 `♻️ refactor: 하루치 버리기를 조회 없는 삭제로 바꾼다`

## Task 3: 하루치 워치 — 권한을 운동 시작 때 묻는다

**Files:** Modify `WatchApp/WatchApp.swift`, `WatchApp/Features/Workout/WorkoutViewModel.swift`, `WatchApp/Features/Workout/Start/StartView.swift` (모두 `Apps/HaruchiFit/` 아래)

- [ ] **Step 1:** `WatchApp.swift` 에서 `.task { _ = await viewModel.requestAuthorization() }` 를 지운다
- [ ] **Step 2:** `WorkoutViewModel`
  - `@Published private(set) var isStarting = false` 추가
  - `requestAuthorization()` 를 지운다 (호출부가 없어진다)
  - `start()` 를 비동기로 바꾼다. **권한 결정 → 세션 시작 → 화면 전환** 순서. 이미 결정한 사용자는 시트 없이 바로 돌아온다

```swift
/// 권한은 **여기서** 묻는다 — 앱을 켤 때가 아니라 운동을 시작하려는 순간이라 이유가 분명하다 (골프·Ralli 와 같다).
/// 결정을 기다린 뒤 시계를 연다. 먼저 열면 첫 실행 때 시트를 보는 시간이 첫 구간에 섞인다.
/// 거부해도 진행한다 — 세션은 조용히 안 열리지만 구간 시계와 저장은 앱이 소유한다.
func start() async {
    guard phase == .idle, !isStarting else { return }
    isStarting = true
    defer { isStarting = false }

    _ = await session.requestAuthorization()
    session.startWorkout()
    phase = .active
    WKInterfaceDevice.current().play(.start)
    segments.reset()
    publishSnapshot(isPaused: false)
}
```

- [ ] **Step 3:** `StartView` — `Button("운동 시작") { Task { await viewModel.start() } }` 에 `.disabled(viewModel.isStarting)`
- [ ] **Step 4:** 하루치 워치 빌드 + `HaruchiFitWatchTests` 통과. 테스트에 `start()` 호출부가 있으면 `await` 를 붙인다
- [ ] **Step 5:** 커밋 `✨ feat: 하루치 워치가 운동 시작 때 건강 권한을 묻는다`

## Task 4: 하루치 워치 설명 문구

**Files:** Modify `Apps/HaruchiFit/WatchApp/InfoPlist.xcstrings`

| 키 | 지금 | 바꿀 문구 |
|---|---|---|
| `NSHealthShareUsageDescription` (ko) | 운동 기록을 가져와 잔디를 채우기 위해 건강 앱 데이터를 읽습니다. | **운동 중 심박수와 칼로리를 측정합니다.** |
| `NSHealthShareUsageDescription` (en) | Haruchi Fit reads your workouts from Apple Health to fill in your activity grid. | **Haruchi Fit measures your heart rate and calories during workouts.** |
| `NSHealthUpdateUsageDescription` | 애플워치로 기록한 운동을 건강 앱에 저장합니다. | 그대로 |

- [ ] **pbxproj 의 워치 타깃(Debug·Release 두 곳) `INFOPLIST_KEY_NSHealthShareUsageDescription` 영문도 같은 문장으로 바꾼다.**
      카탈로그만 고치면 Xcode 가 추출할 때마다 빌드 설정의 옛 영어 문구로 되돌리고 ko 를 `needs_review` 로 바꾼다 —
      Ralli #10 에서 겪고 `022ee1fb` 로 고쳤다. iOS 타깃 두 곳은 건드리지 않는다 (같은 문구지만 iOS 는 실제로 운동을 읽는다)
- [ ] 커밋 `🔧 chore: 하루치 워치 건강 권한 문구를 워치 맥락으로 고친다`

## Task 5: 시뮬레이터 확인

권한을 미결정으로 되돌리려면 **워치 시뮬레이터를 erase** 한다 (앱 재설치로는 안 된다).

- [ ] **Ralli 워치** — erase → 설치 → 매치 시작 → 시트가 **쓰기 1 + 읽기 3** → 허용 → 3분 이상 → 종료. 심박·휴식 칼로리가 나온다
- [ ] **골프 워치** — erase → 라운드 시작 → 시트가 **쓰기 1 + 읽기 5**
- [ ] **하루치 워치** — erase → 앱을 켜도 **시트가 안 뜬다** → `운동 시작` → 시트 → 허용 → W1 으로 넘어간다
- [ ] 하루치 — 시트가 떠 있는 동안 `운동 시작` 을 다시 눌러도 세션이 두 번 열리지 않는다
- [ ] 하루치 — 3분 이상 → 종료 → **버리기** → 확인 후 W0 로 돌아온다. 건강 앱에서 실제로 지워졌는지는 실기기 항목에서 본다
- [ ] 하루치 — erase 후 시트에서 **거부** → 운동이 시작되고 구간 전환·종료·저장이 된다 (kcal·심박은 비어도 됨)

## Task 6: PR

- [ ] `make lint` · `make format`
- [ ] PR 하나 — 본문에 §스파이크 결과 표와 Task 0 결과를 붙인다
- [ ] TODO.md 의 이 행을 취소선 + `완료 (PR #n)` 으로 — **완료 커밋과 같은 커밋에서**

## 실기기 확인 (머지 후, 하루치 실기기 테스트 묶음에 끼운다)

시트 줄 수는 실기기에서 권한을 미결정으로 되돌리기 어려워 **시뮬레이터(Task 5)로 갈음한다.** 실기기는 기능만 본다.

- [ ] 하루치 워치 — 운동 시작 → 저장 → 피트니스 앱에 kcal·심박
- [ ] 하루치 워치 — 버리기 → **건강 앱에서도 운동이 사라진다** (`deleteObjects` 로 바꾼 경로)
- [ ] 하루치 iOS — 앱을 켜면 **운동 읽기 1줄짜리** 시트가 뜬다 (워치가 운동 읽기를 더 묻지 않으므로). 온보딩 전까지의 의도된 동작

### GolfCounter — 골프 앱 다음 업데이트를 출시하기 전에

YJKit 을 고치면 골프의 다음 빌드에도 이 변경이 들어간다. **그 버전을 내보내기 전에** 확인한다 (§기존 동작 8).

- [ ] 아이폰 건강 앱 › 프로필 › 앱 › GolfCounter › **쓰기**에서 활동·휴식 에너지 · 심박수 · **걷기+달리기 거리 · 걸음 수**를 끈다 (운동은 켜 둠)
- [ ] 실제로 걸으며 라운드를 5분 이상 진행하고 저장
- [ ] 폰 기록의 **거리 · 걸음 수 · kcal** 이 0 이 아닌가
- [ ] 피트니스 앱 운동 상세에 거리가 보이는가
- [ ] 끝나면 끈 토글을 다시 켠다

실패한 데이터가 있으면 골프만 그 쓰기를 되살린다 (§결정 사항 아래 대안).

---

## 실행 기록

(Task 0 결과와 실행 중 바뀐 결정을 여기 적는다)

### 2026-10-11 — Task 0 실기기 확인 (Ralli) · 통과

출시된 Ralli 그대로, 아이폰 건강 앱에서 쓰기 권한을 **운동만 켜고** 심박수 · 활동 에너지 · 휴식 에너지를 끈 뒤 실제로 움직이며 진행했다.
읽기 4종(심박수 · 운동 · 활동 에너지 · 휴식 에너지)은 전체 접근 그대로였다.

| 항목 | 결과 |
|---|---|
| 운동 저장 | 피트니스 앱에 테니스 · 오후 9:02~9:09 · 출처 Ralli |
| 운동 시간 | 6분 10초 |
| 활동 칼로리 | **22 kcal** |
| 총 칼로리 | 32 kcal |
| 평균 심박 | 83 BPM · 심박 그래프 표시 |
| Ralli 앱 기록 | 22 kcal · 83 BPM — 피트니스 앱과 같다 |

- **칼로리·심박 쓰기 권한 없이도 활동 칼로리가 운동 기록에 남는다.** 시뮬레이터 스파이크가 판정하지 못한 마지막 값이다.
- 하루치는 같은 `WorkoutSessionService` 에 같은 4종을 쓰므로 이 결과가 그대로 적용된다.
- 이 테스트의 권한 상태는 "거부"다. 새로 설치한 사용자의 "아직 안 물어봄"과는 다르지만 둘 다 쓰기 권한이 없다는 점은 같다.
- **보지 않은 것:** 건강 앱 데이터 보기의 샘플 출처 · **GolfCounter (거리 · 걸음 수)**.
- **결정:** GolfCounter 확인은 구현 전 관문에서 빼고, 골프 앱 다음 업데이트 때 출시 전에 한다 (§실기기 확인).
