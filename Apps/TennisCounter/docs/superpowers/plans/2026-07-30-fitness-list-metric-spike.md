# 피트니스 목록 대표 지표 조사 스파이크 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 애플 피트니스 앱 운동 **목록**에서 Ralli 기록이 kcal 대신 시간으로 표시되는 원인을 특정하고, 고칠 수 있는지 없는지 **결론을 낸다**.

**Architecture:** 이것은 기능 구현이 아니라 **타임박스 조사**다. DEBUG 전용 덤프 코드로 애플 운동 앱이 저장한 테니스 워크아웃과 Ralli가 저장한 워크아웃의 `HKWorkout` 전체를 나란히 찍어 비교하고, 차이에서 가설을 세워 검증한다. 조사가 끝나면 덤프 코드는 지운다.

**Tech Stack:** HealthKit(`HKWorkout`, `HKSampleQuery`, `HKStatistics`), Swift Testing(해당 없음 — 이 계획은 실기기 관찰이 산출물이다).

**연관 문서:** `docs/superpowers/specs/2026-07-30-post-persistence-app-improvements-design.md` (③ 절)

## Global Constraints

- **선행 조건**: `docs/superpowers/plans/2026-07-30-total-calories.md`(① 총 칼로리)를 **먼저 완료하고 실기기 검증까지 마친 뒤** 착수한다. basal 샘플이 워크아웃에 붙는지 여부가 이 조사의 핵심 실험 변수 중 하나다.
- **알려진 사실 (재조사 금지)**:
  - 애플 개발자 포럼 [thread 679835](https://developer.apple.com/forums/thread/679835)에서 동일 문제가 제기됐고 **미해결**이다. 목록의 값을 지정하는 공식 API도, 문서화된 `HKMetadataKey`도 없다.
  - [thread 725572](https://developer.apple.com/forums/thread/725572)의 "에너지 샘플을 워크아웃에 붙여야 한다"는 해법은 **이 문제와 다른 문제**다(그건 무브링 미반영 건). Ralli는 이미 `HKLiveWorkoutBuilder`를 쓰므로 샘플이 붙어 있고, **상세 화면에는 kcal이 정상 표시된다**(사용자 확인).
  - 따라서 이 조사는 "데이터가 빠졌는가"가 아니라 "**피트니스 앱이 무엇을 보고 대표 지표를 고르는가**"를 찾는 것이다.
- **이 머신의 destination**: `<IOS_DEST>` = `platform=iOS Simulator,id=CB44AC14-F009-482F-9F4B-712B87A1CB72`
- **덤프 코드는 `#if DEBUG`로 감싼다.** 릴리즈 빌드에 절대 포함되지 않아야 하며, Task 4에서 제거한다.
- **읽기 전용 조사다.** 기존 워크아웃 데이터를 수정하거나 삭제하지 않는다.
- **타임박스**: 실기기 실험 2회(①반영 전/후) + 덤프 분석. 그 안에 단서가 안 나오면 "시스템 동작"으로 결론짓고 종료한다. 이 계획은 **결론 없이 무한정 늘어나지 않는 것**이 성공 조건의 일부다.
- 커밋: gitmoji + 한국어. 계획·스펙 문서는 사용자 검토 전까지 커밋하지 않는다.

## File Structure

| 파일 | 역할 | 태스크 |
|---|---|---|
| `iOSApp/Services/WorkoutDumpService.swift` | (신규, DEBUG 전용) 최근 테니스 워크아웃 전수 덤프. Task 4에서 삭제 | 1, 4 |
| `iOSApp/Features/Summary/SummaryView.swift` | (DEBUG 전용) 덤프 실행 버튼. Task 4에서 원복 | 1, 4 |
| `docs/superpowers/logs/2026-07-30-fitness-list-metric-spike.md` | 관찰 기록과 결론 — **이 계획의 진짜 산출물** | 2, 3, 4 |

---

### Task 1: DEBUG 전용 워크아웃 덤프 도구

**Files:**
- Create: `iOSApp/Services/WorkoutDumpService.swift`
- Modify: `iOSApp/Features/Summary/SummaryView.swift` (DEBUG 전용 버튼 추가)

**Interfaces:**
- Consumes: 없음
- Produces: `WorkoutDumpService.dumpRecentTennisWorkouts(limit:)` — 최근 테니스 워크아웃들의 전체 속성을 콘솔에 출력한다. Task 2가 이 출력을 읽는다.

- [ ] **Step 1: 덤프 서비스 작성**

`iOSApp/Services/WorkoutDumpService.swift` 신규 생성:

```swift
#if DEBUG
    import Foundation
    import HealthKit

    /// 조사 스파이크 전용 도구 — 피트니스 목록이 kcal 대신 시간을 보여주는 원인을 찾기 위해
    /// 애플 운동 앱과 Ralli가 저장한 HKWorkout을 전수 비교한다.
    /// **조사가 끝나면 이 파일을 삭제한다** (docs/superpowers/plans/2026-07-30-fitness-list-metric-spike.md Task 4).
    enum WorkoutDumpService {
        private static let store = HKHealthStore()

        static func dumpRecentTennisWorkouts(limit: Int = 6) async {
            guard HKHealthStore.isHealthDataAvailable() else {
                print("[DUMP] HealthKit 사용 불가")
                return
            }
            do {
                try await store.requestAuthorization(toShare: [], read: [HKObjectType.workoutType()])
            } catch {
                print("[DUMP] 권한 요청 실패: \(error)")
                return
            }

            let workouts = await fetchTennisWorkouts(limit: limit)
            guard !workouts.isEmpty else {
                print("[DUMP] 테니스 워크아웃이 없다")
                return
            }

            for workout in workouts {
                dump(workout)
            }
        }

        private static func fetchTennisWorkouts(limit: Int) async -> [HKWorkout] {
            await withCheckedContinuation { continuation in
                let predicate = HKQuery.predicateForWorkouts(with: .tennis)
                let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
                let query = HKSampleQuery(
                    sampleType: HKObjectType.workoutType(),
                    predicate: predicate,
                    limit: limit,
                    sortDescriptors: [sort]
                ) { _, samples, error in
                    if let error { print("[DUMP] 조회 실패: \(error)") }
                    continuation.resume(returning: samples as? [HKWorkout] ?? [])
                }
                store.execute(query)
            }
        }

        private static func dump(_ workout: HKWorkout) {
            print("========================================")
            print("[DUMP] source     : \(workout.sourceRevision.source.name)")
            print("[DUMP] bundleId   : \(workout.sourceRevision.source.bundleIdentifier)")
            print("[DUMP] version    : \(workout.sourceRevision.version ?? "-")")
            print("[DUMP] osVersion  : \(workout.sourceRevision.operatingSystemVersion)")
            print("[DUMP] device     : \(workout.device?.name ?? "-") / \(workout.device?.model ?? "-")")
            print("[DUMP] start      : \(workout.startDate)")
            print("[DUMP] duration   : \(workout.duration)")
            print("[DUMP] eventCount : \(workout.workoutEvents?.count ?? 0)")
            print("[DUMP] activities : \(workout.workoutActivities.count)")

            print("[DUMP] --- metadata ---")
            if let metadata = workout.metadata, !metadata.isEmpty {
                for key in metadata.keys.sorted() {
                    print("[DUMP]   \(key) = \(String(describing: metadata[key]))")
                }
            } else {
                print("[DUMP]   (없음)")
            }

            print("[DUMP] --- statistics ---")
            let types: [(String, HKQuantityType, HKUnit)] = [
                ("activeEnergy", HKQuantityType(.activeEnergyBurned), .kilocalorie()),
                ("basalEnergy", HKQuantityType(.basalEnergyBurned), .kilocalorie()),
                ("heartRate", HKQuantityType(.heartRate), HKUnit(from: "count/min")),
                ("distanceWalkingRunning", HKQuantityType(.distanceWalkingRunning), .meter()),
                ("stepCount", HKQuantityType(.stepCount), .count()),
            ]
            for (label, type, unit) in types {
                if let stats = workout.statistics(for: type) {
                    let sum = stats.sumQuantity()?.doubleValue(for: unit)
                    let avg = stats.averageQuantity()?.doubleValue(for: unit)
                    print("[DUMP]   \(label): sum=\(sum.map { String(format: "%.1f", $0) } ?? "-") avg=\(avg.map { String(format: "%.1f", $0) } ?? "-")")
                } else {
                    print("[DUMP]   \(label): (통계 없음)")
                }
            }
            print("========================================")
        }
    }
#endif
```

- [ ] **Step 2: 실행 버튼 배선 (DEBUG 전용)**

`iOSApp/Features/Summary/SummaryView.swift`의 최상위 `body` 안, 가장 바깥 컨테이너의 마지막에 다음 modifier를 붙인다 (기존 레이아웃을 건드리지 않는 툴바 항목이다):

```swift
        #if DEBUG
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("DUMP") {
                        Task { await WorkoutDumpService.dumpRecentTennisWorkouts() }
                    }
                }
            }
        #endif
```

이미 `.toolbar { ... }`가 있으면 그 안에 `ToolbarItem`만 `#if DEBUG`로 감싸 추가한다.

- [ ] **Step 3: 빌드 확인**

```bash
cd /Users/yj/Workspace/tennis_counter
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' build 2>&1 | tail -5
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' -configuration Release build 2>&1 | tail -5
```

Expected: 둘 다 BUILD SUCCEEDED. **Release 빌드가 성공해야 `#if DEBUG` 격리가 제대로 된 것이다** — Release에서 `WorkoutDumpService`를 못 찾는다는 에러가 나면 버튼 쪽 `#if DEBUG`가 빠진 것이다.

- [ ] **Step 4: 린트 + 커밋**

```bash
cd /Users/yj/Workspace/tennis_counter
make fix && make lint
git add iOSApp/Services/WorkoutDumpService.swift iOSApp/Features/Summary/SummaryView.swift
git commit -m "🔍 조사용 HKWorkout 덤프 도구 (DEBUG 전용, 조사 후 제거)

피트니스 목록이 kcal 대신 시간을 보여주는 원인을 찾기 위해
애플 운동 앱과 Ralli의 워크아웃을 전수 비교한다.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: [사용자 수동] 실기기 관찰 1회차 — 대조군 확보

**⚠️ 실기기에서만 가능하다.** 시뮬레이터에는 애플 운동 앱이 없고 워크아웃 세션도 동작하지 않는다.

**Interfaces:**
- Consumes: Task 1의 `WorkoutDumpService`
- Produces: `docs/superpowers/logs/2026-07-30-fitness-list-metric-spike.md`에 기록된 두 워크아웃의 덤프 비교표. Task 3이 이를 근거로 가설을 검증한다.

- [ ] **Step 1: [사용자] 대조군·실험군 기록 생성**

1. Apple Watch의 **애플 운동 앱**으로 테니스 운동을 **5분 이상** 진행하고 종료 (대조군)
2. **Ralli**로 테니스 워크아웃을 **5분 이상** 진행하고 경기 저장 후 종료 (실험군)
3. 폰의 피트니스 앱 → 운동 목록에서 **두 기록의 초록색 값이 각각 무엇인지** 확인하고 기록한다
   - 애플 운동 앱 기록: kcal? 시간?
   - Ralli 기록: 시간 (현상 재확인)

- [ ] **Step 2: [사용자] 덤프 실행 후 콘솔 캡처**

Xcode로 폰에 Debug 빌드를 설치하고 실행 → Summary 탭 → 우상단 **DUMP** 버튼 탭 → Xcode 콘솔의 `[DUMP]` 출력 전체를 복사한다.

- [ ] **Step 3: 기록 문서 작성**

`docs/superpowers/logs/2026-07-30-fitness-list-metric-spike.md`를 다음 뼈대로 생성하고 채운다:

```markdown
# 피트니스 목록 대표 지표 조사

## 작업일: 2026-07-30

## 현상

피트니스 앱 운동 목록에서 Ralli 기록의 초록색 값이 kcal이 아니라 시간으로 표시된다.
운동 **상세** 화면에서는 kcal이 정상 표시되므로 데이터 누락이 아니다.

## 사전 조사 (구현 전)

- 애플 개발자 포럼 thread 679835 — 동일 문제, **미해결**. 목록 값을 지정하는 공식 API·메타데이터 키 없음.
- thread 725572의 "에너지 샘플 첨부" 해법은 무브링 미반영 건이라 이 문제와 다르다.

## 1회차 관찰 (① 총 칼로리 반영 후)

| 항목 | 애플 운동 앱 (대조군) | Ralli (실험군) |
|---|---|---|
| 목록 초록색 값 | (채울 것) | (채울 것) |
| sourceRevision.version | | |
| device.name / model | | |
| metadata 키 목록 | | |
| activeEnergy sum | | |
| basalEnergy sum | | |
| distanceWalkingRunning sum | | |
| stepCount sum | | |
| workoutEvents 개수 | | |
| workoutActivities 개수 | | |

### 덤프 원문

```
(콘솔 [DUMP] 출력 붙여넣기)
```

### 눈에 띄는 차이

(채울 것)

## 가설

(채울 것)

## 결론

(Task 4에서 채울 것)
```

- [ ] **Step 4: 차이점 분석**

두 덤프를 비교해 **Ralli에만 없거나 다른 것**을 전부 나열한다. 특히 다음을 확인한다:

- `metadata`에 애플 운동 앱만 갖고 있는 키가 있는가 (예: `HKIndoorWorkout`, `HKWeatherTemperature`, `HKAverageMETs`)
- `basalEnergy` 통계가 Ralli에도 있는가 (①이 제대로 붙었는지)
- `distanceWalkingRunning`·`stepCount` 통계가 애플 쪽에만 있는가 — **거리 통계의 유무가 대표 지표 선택을 바꾼다는 가설이 가장 유력한 후보다** (러닝·사이클은 거리, 실내 운동은 kcal이 목록에 뜨는 패턴과 일치)
- `workoutActivities`(watchOS 10+ 다중 액티비티) 구조가 다른가

찾은 차이를 기록 문서의 "눈에 띄는 차이"와 "가설"에 적는다.

---

### Task 3: [사용자 수동] 가설 검증 2회차

**Interfaces:**
- Consumes: Task 2의 가설
- Produces: 검증 결과. Task 4가 이를 근거로 결론을 확정한다.

- [ ] **Step 1: 가설에 따른 최소 변경 적용**

Task 2에서 가장 유력한 가설 **하나만** 골라 최소 변경을 적용한다. 유력도 순서와 각 변경 방법:

**가설 A — `HKAverageMETs` 메타데이터 부재**
`WorkoutSessionService.stopWorkout()`에서 `builder.endCollection` 전에 메타데이터를 추가한다:

```swift
try? await builder.addMetadata([HKMetadataKeyAverageMETs: HKQuantity(unit: HKUnit(from: "kcal/(kg*hr)"), doubleValue: 6.0)])
```

**가설 B — `HKIndoorWorkout` 플래그 부재**

```swift
try? await builder.addMetadata([HKMetadataKeyIndoorWorkout: false])
```

**가설 C — 거리 통계 부재**
`WorkoutConfiguration.tennis`의 `locationType`이 `.outdoor`인데 거리 데이터가 없어서 애매한 상태일 수 있다. `.indoor`로 바꿔 실험한다 (`WatchApp/Features/WorkoutSession/WorkoutConfiguration+Tennis.swift`):

```swift
static let tennis = WorkoutConfiguration(activityType: .tennis, locationType: .indoor)
```

**한 번에 하나씩만 바꾼다.** 여러 개를 동시에 바꾸면 무엇이 효과가 있었는지 알 수 없다.

- [ ] **Step 2: [사용자] 재실험**

변경한 빌드로 테니스 워크아웃 5분 이상 → 종료 → 피트니스 앱 목록 확인 → DUMP 재실행.

- [ ] **Step 3: 결과 기록**

기록 문서에 "2회차 검증" 절을 추가하고, 어떤 가설을 어떻게 바꿨는지와 목록 표시가 바뀌었는지를 적는다.

- [ ] **Step 4: 타임박스 판정**

- **목록이 kcal로 바뀌었다** → 그 변경을 정식 커밋으로 남기고 Task 4로. 실험용 임시 코드였다면 정리해서 커밋한다.
- **안 바뀌었다** → 남은 가설이 있으면 **최대 1개만 더** 시도한다(합계 3회차). 그래도 안 되면 **"시스템 동작 — 수정 불가"로 결론짓고 Task 4로 간다.** 여기서 멈추는 것이 이 계획의 설계된 종료 조건이다.

---

### Task 4: 결론 확정 + 조사 코드 제거

**Files:**
- Delete: `iOSApp/Services/WorkoutDumpService.swift`
- Modify: `iOSApp/Features/Summary/SummaryView.swift` (DUMP 버튼 원복)
- Modify: `docs/superpowers/logs/2026-07-30-fitness-list-metric-spike.md` (결론)

- [ ] **Step 1: 결론 작성**

기록 문서의 "결론" 절을 다음 중 하나로 채운다.

**해결한 경우:**

```markdown
## 결론 — 해결

원인: (무엇이 빠져 있었는지)
수정: (어떤 커밋으로 무엇을 바꿨는지)
검증: 피트니스 목록에서 Ralli 기록이 (값)로 표시됨을 실기기에서 확인 (날짜)
```

**해결 못 한 경우:**

```markdown
## 결론 — 수정 불가 (시스템 동작)

피트니스 앱이 운동 목록의 대표 지표를 고르는 규칙은 공개 API로 제어할 수 없다.
검증한 가설: (목록)과 각각의 결과.
애플 개발자 포럼 thread 679835에서도 같은 결론이며, 문서화된 메타데이터 키가 없다.

**재검토 트리거**: 새 watchOS/iOS 메이저 버전의 HealthKit 릴리즈 노트에
워크아웃 표시 관련 API가 추가되면 다시 본다. 그때까지 추가 시도를 하지 않는다.
```

- [ ] **Step 2: 조사 코드 제거**

```bash
cd /Users/yj/Workspace/tennis_counter
rm iOSApp/Services/WorkoutDumpService.swift
```

`iOSApp/Features/Summary/SummaryView.swift`에서 Task 1 Step 2에서 넣은 `#if DEBUG` 툴바 블록을 삭제한다 (기존에 `.toolbar`가 없었다면 modifier 전체를, 있었다면 추가한 `ToolbarItem`만).

- [ ] **Step 3: 제거 확인 + 빌드**

```bash
cd /Users/yj/Workspace/tennis_counter
grep -rn "WorkoutDumpService\|DUMP" --include="*.swift" .
```

Expected: 출력 없음

```bash
xcodebuild test -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' 2>&1 | tail -20
xcodebuild -project TennisCounter.xcodeproj -scheme "TennisCounter" -destination '<IOS_DEST>' -configuration Release build 2>&1 | tail -5
```

Expected: TEST SUCCEEDED, BUILD SUCCEEDED

- [ ] **Step 4: 린트 + 커밋**

```bash
cd /Users/yj/Workspace/tennis_counter
make fix && make lint
git add iOSApp docs/superpowers/logs/2026-07-30-fitness-list-metric-spike.md
git commit -m "🔥 조사 종료 — 덤프 도구 제거, 결론은 로그에 기록

피트니스 목록 대표 지표 조사 결과를 logs에 남기고
DEBUG 전용 덤프 코드를 제거했다.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## 완료 기준 (Definition of Done)

1. `docs/superpowers/logs/2026-07-30-fitness-list-metric-spike.md`에 **두 워크아웃의 덤프 비교표가 채워져 있고**, "결론" 절이 "해결" 또는 "수정 불가" 중 하나로 명확히 적혀 있다
2. `grep -rn "WorkoutDumpService\|DUMP" --include="*.swift" .` → 0건
3. iOS 테스트 스위트 그린 + Release 빌드 그린
4. `make lint` 위반 0건
5. 실기기 실험 **최대 3회**로 종료했다 — 결론이 "수정 불가"여도 완료다. 이 계획에서 결론이 안 난 채로 남는 것만이 실패다.
