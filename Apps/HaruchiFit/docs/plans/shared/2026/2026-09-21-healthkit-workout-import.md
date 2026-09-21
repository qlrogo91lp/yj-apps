# HealthKit 워크아웃 import — 구현 플랜

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 다른 앱이 건강 앱에 저장한 워크아웃을 매핑 표로 걸러 데려온다. 우리가 이미 가진 기록은 건드리지 않는다. **삭제 반영은 이 작업에 없다** — 3개 앱에 걸리는 문제라 YJKit 범위로 옮겼다 (스펙 4절).

**Architecture:** 규칙은 전부 `Shared/Services/` 의 순수 타입(`WorkoutTypeMapping` · `ImportedWorkout` · `WorkoutImportPlanner`)과 `Shared/Persistence/WorkoutRecord+Import` 가 갖는다. `iOSApp/Services/` 는 HealthKit 쿼리·앵커·배선만 한다 — **iOS 테스트 타깃이 없어 거기 둔 것은 아무도 검증하지 못하기 때문이다.**

**Tech Stack:** Swift 6 · SwiftUI · SwiftData · HealthKit · swift-testing (`@Test`/`#expect`) · iOS 17 / watchOS 10

**Spec:** [`docs/specs/shared/2026/2026-09-21-healthkit-workout-import.md`](../../specs/shared/2026/2026-09-21-healthkit-workout-import.md)

## Global Constraints

- **`Packages/YJKit` 을 한 줄도 고치지 않는다.** `WorkoutSessionService.requestAuthorization()` 은 `WorkoutConfiguration` 을 요구하고 쓰기 권한까지 요청한다 — 폰의 읽기 전용 경로에 맞지 않아 **재사용하지 않는다** (스펙 7절). 패키지를 건드리면 CI 가 3개 앱을 전부 빌드한다
- **순수 규칙은 `Shared/` 에 둔다.** `Shared/` 는 iOS·워치 양쪽 타깃에 붙어 `HaruchiFitWatchTests` 가 그대로 본다. `iOSApp/` 은 iOS 전용이라 유닛 테스트가 불가능하다
- **`Common/` 에 아무것도 더하지 않는다.** 컴플리케이션 타깃이 붙는 폴더고 **외부 의존이 0 이어야 한다** — HealthKit 을 import 하는 파일을 두면 안 된다
- **`healthKitUUID` 를 이미 가진 레코드는 import 가 건드리지 않는다** (스펙 3절 · 잔디 스펙 6절). 갱신도, 덮어쓰기도 없다. 워치 기록의 `totalSeconds` 는 정지를 뺀 앱의 값이고 `HKWorkout.duration` 과 다르다
- **매핑 표에 없는 타입은 import 하지 않는다** (D-M5). 걸러내는 곳은 **입구 한 군데뿐**이다 — `GrassAggregator` 는 필터를 갖지 않는다 (잔디 스펙 4.5)
- **import 기록은 세그먼트를 정확히 1 개 갖는다** (스펙 5절). 집계 경로를 둘로 가르지 않기 위해서다
- **HealthKit 읽기 권한은 상태를 알 수 없다** (스펙 7절). 거부를 감지하려 들지 말고, 빈 결과를 빈 결과로 끝낸다
- **저장은 배치로.** `PersistenceService.upsert` 는 건당 `save()` 라 첫 동기화에 맞지 않는다 — 읽기에만 쓰고 쓰기는 `ModelContext` 를 직접 만진다
- **앵커는 적용이 성공한 뒤에 저장한다.** 먼저 저장하면 실패한 배치를 영영 다시 못 읽는다
- ViewModel·코디네이터는 UI 프레임워크를 import 하지 않는다 (루트 `CLAUDE.md`)
- 빌드·테스트는 **워크스페이스 기준**이다. 시뮬레이터는 이름이 아니라 UDID 로 지정한다
- 커밋 메시지는 gitmoji prefix (`✨ feat` / `✅ test` / `📝 docs`)

**명령** (저장소 루트에서):

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')

# 순수 규칙 테스트
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test

# iOS — 테스트 타깃이 없다. 빌드만.
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFit" -destination "id=$IOS" build

# 코드 스타일
make lint && make format
```

## File Structure

```
Apps/HaruchiFit/
├─ Shared/
│  ├─ Services/
│  │  ├─ WorkoutTypeMapping.swift        [신규] 매핑 표 — 유일한 필터
│  │  ├─ ImportedWorkout.swift           [신규] HealthKit 을 떠난 순수 값
│  │  └─ WorkoutImportPlanner.swift      [신규] 무엇을 새로 넣을지 — 불변조건이 여기 산다
│  └─ Persistence/
│     └─ WorkoutRecord+Import.swift      [신규] ImportedWorkout → WorkoutRecord
├─ iOSApp/
│  ├─ Services/
│  │  ├─ WorkoutQueryAnchorStore.swift   [신규] 앵커 영속화
│  │  ├─ HealthKitWorkoutImporter.swift  [신규] 앵커드 쿼리 + 권한 + 값 추출
│  │  └─ WorkoutSyncCoordinator.swift    [신규] 배선
│  ├─ iOSApp.swift                       [수정] 코디네이터 주입 · scenePhase 트리거
│  └─ ContentView.swift                  [수정] .refreshable
└─ watchosTests/
   ├─ Support/ImportFixture.swift        [신규] ImportedWorkout 픽스처
   └─ Import/
      ├─ WorkoutTypeMappingTests.swift   [신규]
      ├─ WorkoutImportPlannerTests.swift [신규]
      └─ WorkoutRecordImportTests.swift  [신규]
```

**Xcode 수작업 없음** — `PBXFileSystemSynchronizedRootGroup` 이라 파일 생성만으로 타깃에 붙는다. `watchosTests/Import/` 가 새 폴더지만 동기화 루트 아래라 같다. HealthKit Capability 와 `NSHealthShareUsageDescription` 은 **iOS 타깃에 이미 들어 있다** (`HaruchiFit.entitlements` · pbxproj 확인 완료).

---

## Task 0: 워크트리와 브랜치를 판다

**Files:** 없음

- [ ] **Step 1: 워크트리 생성**

  네이티브 도구(`EnterWorktree`)가 있으면 그것을 쓴다. 없을 때만 직접 판다 — 경로는 **형제 폴더**다:

  ```bash
  git worktree add ../yj-apps-worktrees/healthkit-workout-import -b feat/healthkit-workout-import
  ```

  저장소 안(`.worktrees/`)이나 에이전트 워크스페이스에 두지 않는다. 전자는 `PBXFileSystemSynchronizedRootGroup` 의 자동 스캔 대상이 될 수 있고, 후자는 세션이 끝나면 회수되는데 **이 작업은 실기기 확인이 6항목 남는다**.

- [ ] **Step 2: 베이스라인 확인**

  손대기 전에 현재 상태가 초록인지 본다. 여기서 깨져 있으면 그건 이 작업의 문제가 아니다.

  ```bash
  xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
  xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFit" -destination "id=$IOS" build
  ```

---

## Task 1: 매핑 표

**Files:**

- Create: `Shared/Services/WorkoutTypeMapping.swift`
- Create: `watchosTests/Import/WorkoutTypeMappingTests.swift`

이 표가 **D-M5 를 지키는 유일한 지점**이다. 집계기는 필터를 갖지 않는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

  ```swift
  import HealthKit
  @testable import HaruchiFit_Watch_App
  import Testing

  /// 매핑 표는 **D-M5 를 지키는 유일한 지점**이다. 집계기는 필터를 갖지 않는다 (잔디 스펙 4.5).
  struct WorkoutTypeMappingTests {
      @Test("근력 3종", arguments: [
          HKWorkoutActivityType.traditionalStrengthTraining,
          .functionalStrengthTraining,
          .coreTraining,
      ])
      func strengthTypes(_ type: HKWorkoutActivityType) {
          #expect(WorkoutTypeMapping.kind(for: type) == .strength)
      }

      @Test("유산소 8종", arguments: [
          HKWorkoutActivityType.running,
          .walking,
          .cycling,
          .elliptical,
          .rowing,
          .stairClimbing,
          .stepTraining,
          .highIntensityIntervalTraining,
      ])
      func cardioTypes(_ type: HKWorkoutActivityType) {
          #expect(WorkoutTypeMapping.kind(for: type) == .cardio)
      }

      /// **.other · .mixedCardio · .crossTraining 을 뺀 것이 이 표의 핵심 판단이다** (스펙 2절).
      /// 사용자가 그 안에 무엇을 넣었는지 앱이 알 수 없고, 오분류가 Phase 4 비율 차트의 분모로 들어간다.
      @Test("표에 없는 타입은 import 하지 않는다", arguments: [
          HKWorkoutActivityType.other,
          .mixedCardio,
          .crossTraining,
          .yoga,
          .pilates,
          .swimming,
          .hiking,
          .tennis,
          .golf,
      ])
      func unmappedTypesAreNil(_ type: HKWorkoutActivityType) {
          #expect(WorkoutTypeMapping.kind(for: type) == nil)
      }
  }
  ```

  `.tennis` · `.golf` 를 넣어 둔 것은 **Ralli·GolfCounter 가 저장한 워크아웃이 잔디에 안 들어온다**는 D-M5 의 대가를 테스트가 붙들어 두기 위해서다.

- [ ] **Step 2: 실패를 확인한다**

  컴파일 에러로 실패한다 (`WorkoutTypeMapping` 이 없다). 그게 맞는 실패다.

- [ ] **Step 3: 매핑 표를 만든다**

  ```swift
  import HealthKit

  /// `HKWorkoutActivityType` 을 하루치 핏의 구간 종류로 옮긴다.
  ///
  /// **표에 없는 타입은 nil 이고, nil 은 "가져오지 않는다" 는 뜻이다** (D-M5 · 스펙 2절).
  /// 요가·수영·구기는 물론 `.other` · `.mixedCardio` · `.crossTraining` 도 여기 없다 —
  /// 사용자가 그 안에 무엇을 넣었는지 앱이 알 수 없고, 어느 쪽으로 분류해도 절반은 틀린다.
  ///
  /// ⚠️ **이 표를 고치면 앵커를 버리고 전체를 다시 읽어야 한다.** 앵커만 유지한 채 넓히면
  /// 앞으로 들어올 워크아웃만 새 규칙을 따르고 과거는 옛 규칙에 남아, 같은 종목이 날짜에
  /// 따라 다르게 보인다 (스펙 2절 "변경 시 지켜야 할 것").
  enum WorkoutTypeMapping {
      static func kind(for type: HKWorkoutActivityType) -> SegmentKind? {
          switch type {
          case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining:
              .strength
          case .running, .walking, .cycling, .elliptical, .rowing,
               .stairClimbing, .stepTraining, .highIntensityIntervalTraining:
              .cardio
          default:
              nil
          }
      }
  }
  ```

- [ ] **Step 4: 테스트 통과를 확인한다**

  ```bash
  xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
  ```

- [ ] **Step 5: 커밋**

  ```
  ✨ HealthKit 워크아웃을 근력·유산소로 분류하는 매핑 표를 둔다
  ```

---

## Task 2: 값 타입 · 플래너 · 변환

**Files:**

- Create: `Shared/Services/ImportedWorkout.swift`
- Create: `Shared/Services/WorkoutImportPlanner.swift`
- Create: `Shared/Persistence/WorkoutRecord+Import.swift`
- Create: `watchosTests/Support/ImportFixture.swift`
- Create: `watchosTests/Import/WorkoutImportPlannerTests.swift`
- Create: `watchosTests/Import/WorkoutRecordImportTests.swift`

**스펙 3절의 불변조건이 사는 자리다.** HealthKit 타입이 여기까지 올라오지 않게 한다 — 순수 값만 다뤄야 워치 테스트 타깃에서 돌릴 수 있다.

- [ ] **Step 1: 픽스처를 만든다**

  ```swift
  import Foundation
  @testable import HaruchiFit_Watch_App

  /// import 테스트용 순수 값. `RecordFixture`(워치 전송 페이로드)와 역할이 다르다.
  enum ImportFixture {
      static func workout(uuid: UUID = UUID(),
                          kind: SegmentKind = .cardio,
                          totalSeconds: Int = 1800,
                          activeCalories: Double? = 240,
                          averageHeartRate: Double? = 132) -> ImportedWorkout
      {
          let start = Date(timeIntervalSince1970: 0)
          return ImportedWorkout(uuid: uuid,
                                 kind: kind,
                                 startedAt: start,
                                 endedAt: start.addingTimeInterval(TimeInterval(totalSeconds)),
                                 totalSeconds: totalSeconds,
                                 activeCalories: activeCalories,
                                 averageHeartRate: averageHeartRate)
      }
  }
  ```

- [ ] **Step 2: 실패하는 플래너 테스트를 쓴다**

  ```swift
  import Foundation
  @testable import HaruchiFit_Watch_App
  import Testing

  /// **이미 가진 기록은 건드리지 않는다** — 잔디 스펙 6절의 불변조건이고, 깨지면 과거 잔디
  /// 농도가 소급해서 바뀐다. 워치 기록의 시간은 정지를 뺀 앱의 값이라(PR #26)
  /// `HKWorkout.duration` 과 다르기 때문이다.
  struct WorkoutImportPlannerTests {
      @Test("이미 가진 UUID 는 삽입하지 않는다")
      func existingUUIDIsSkipped() {
          let mine = UUID()
          let inserts = WorkoutImportPlanner.inserts(from: [ImportFixture.workout(uuid: mine),
                                                            ImportFixture.workout()],
                                                     existing: [mine])

          #expect(inserts.count == 1)
          #expect(inserts.contains { $0.uuid == mine } == false)
      }

      @Test("같은 배치에 같은 UUID 가 두 번 오면 한 번만 넣는다")
      func duplicatesWithinBatchCollapse() {
          let uuid = UUID()
          let inserts = WorkoutImportPlanner.inserts(from: [ImportFixture.workout(uuid: uuid),
                                                            ImportFixture.workout(uuid: uuid)],
                                                     existing: [])

          #expect(inserts.count == 1)
      }

      @Test("들어온 순서를 지킨다")
      func preservesOrder() {
          let first = ImportFixture.workout()
          let second = ImportFixture.workout()
          let inserts = WorkoutImportPlanner.inserts(from: [first, second], existing: [])

          #expect(inserts.map(\.uuid) == [first.uuid, second.uuid])
      }

      @Test("가져올 것이 없으면 빈 배열이다")
      func emptyResult() {
          #expect(WorkoutImportPlanner.inserts(from: [], existing: []).isEmpty)
      }
  }
  ```

- [ ] **Step 3: 실패하는 변환 테스트를 쓴다**

  ```swift
  import Foundation
  @testable import HaruchiFit_Watch_App
  import SwiftData
  import Testing

  /// import 기록은 **전환이 0 회인 세션**이다. 세그먼트를 안 만들면 잔디 농도는 채워지는데
  /// 비율 차트에서만 빠지는 절름발이 레코드가 되고, 집계기가 분기를 갖게 된다 (스펙 5절).
  @MainActor
  struct WorkoutRecordImportTests {
      @Test("매핑된 kind 로 전체 길이 세그먼트 1 개를 만든다")
      func makesSingleFullLengthSegment() {
          let record = WorkoutRecord.make(from: ImportFixture.workout(kind: .cardio, totalSeconds: 1800))

          #expect(record.orderedSegments.count == 1)
          #expect(record.orderedSegments.first?.kind == .cardio)
          #expect(record.orderedSegments.first?.startOffset == 0)
          #expect(record.orderedSegments.first?.durationSeconds == 1800)
      }

      /// 다른 앱 워크아웃에는 basal 샘플이 붙어 있지 않다. active 를 그대로 쓰는 편이
      /// nil 보다 낫고 카드·요약이 빈칸을 피한다 (스펙 5절).
      @Test("totalCalories 는 activeCalories 와 같다")
      func totalCaloriesMirrorActive() {
          let record = WorkoutRecord.make(from: ImportFixture.workout(activeCalories: 240))

          #expect(record.activeCalories == 240)
          #expect(record.totalCalories == 240)
      }

      @Test("출처는 healthKitImport 이고 UUID 가 보존된다")
      func sourceAndKey() {
          let uuid = UUID()
          let record = WorkoutRecord.make(from: ImportFixture.workout(uuid: uuid))

          #expect(record.source == .healthKitImport)
          #expect(record.healthKitUUID == uuid)
      }

      /// 집계까지 한 번 이어서 본다 — 세그먼트 1 개가 실제로 cardioSeconds 로 접히는지.
      @Test("import 레코드가 잔디 집계에서 유산소 시간으로 접힌다")
      func foldsIntoCardioSeconds() throws {
          let context = try GrassFixture.makeContext()
          context.insert(WorkoutRecord.make(from: ImportFixture.workout(kind: .cardio, totalSeconds: 1800)))

          let days = GrassAggregator.fold(try context.fetch(FetchDescriptor<WorkoutRecord>()),
                                          calendar: GrassFixture.seoul)

          #expect(days.first?.cardioSeconds == 1800)
          #expect(days.first?.strengthSeconds == 0)
      }
  }
  ```

- [ ] **Step 4: 실패를 확인한다**

- [ ] **Step 5: 세 타입을 만든다**

  `Shared/Services/ImportedWorkout.swift`:

  ```swift
  import Foundation

  /// HealthKit 을 떠난 워크아웃 하나. **`HKWorkout` 이 `Shared/` 위로 올라오지 않게 하는
  /// 경계다** — 순수 값이라야 워치 테스트 타깃에서 규칙을 검증할 수 있다.
  ///
  /// `kind` 는 이미 매핑을 통과한 결과다. 여기까지 온 워크아웃은 전부 잔디에 반영된다.
  struct ImportedWorkout: Equatable, Identifiable {
      let uuid: UUID
      let kind: SegmentKind
      let startedAt: Date
      let endedAt: Date
      /// `HKWorkout.duration` — **일시정지를 뺀 값**이라 워치 기록(PR #26)과 의미가 같다.
      let totalSeconds: Int
      let activeCalories: Double?
      let averageHeartRate: Double?

      var id: UUID {
          uuid
      }
  }
  ```

  `Shared/Services/WorkoutImportPlanner.swift`:

  ```swift
  import Foundation

  /// **import 의 불변조건이 사는 자리다** (스펙 3절 · 잔디 스펙 6절).
  ///
  /// 이미 `healthKitUUID` 를 가진 레코드는 통과시킨다 — 갱신도 하지 않는다. 덮어쓰면
  /// 워치가 잰 시간(정지 제외)이 HealthKit 이 잰 시간으로 바뀌어 **과거 잔디 농도가
  /// 소급해서 달라지고**, 세그먼트·부위·메모까지 날아간다.
  ///
  /// **삭제는 다루지 않는다** — 건강 앱에서 지워진 워크아웃을 따라 지우는 일은 3개 앱에
  /// 걸리는 문제라 YJKit 범위로 옮겼다 (스펙 4절). 그때 이 타입에 `deletions` 가 돌아온다.
  enum WorkoutImportPlanner {
      static func inserts(from imported: [ImportedWorkout],
                          existing: Set<UUID>) -> [ImportedWorkout]
      {
          // 순서를 지키며 중복을 접는다 — Set 으로 바꾸면 삽입 순서가 실행마다 달라진다.
          var seen = Set<UUID>()
          return imported.filter { workout in
              guard !existing.contains(workout.uuid) else { return false }
              return seen.insert(workout.uuid).inserted
          }
      }
  }
  ```

  `Shared/Persistence/WorkoutRecord+Import.swift`:

  ```swift
  import Foundation

  extension WorkoutRecord {
      /// 외부 워크아웃을 레코드로 옮긴다. **세그먼트를 정확히 하나 만든다** — 매핑된 kind 로
      /// 전체 길이를 덮는다 (스펙 5절). 외부 워크아웃은 전환이 0 회인 세션이라 의미도 맞고,
      /// 잔디 집계가 워치 기록과 **같은 경로**로 읽게 된다.
      ///
      /// `totalCalories` 에 active 를 그대로 넣는다 — 다른 앱 워크아웃에는 basal 샘플이
      /// 붙어 있지 않아 따로 구해도 대개 nil 이다.
      static func make(from workout: ImportedWorkout) -> WorkoutRecord {
          let record = WorkoutRecord(healthKitUUID: workout.uuid,
                                     startedAt: workout.startedAt,
                                     endedAt: workout.endedAt,
                                     totalSeconds: workout.totalSeconds,
                                     activeCalories: workout.activeCalories,
                                     totalCalories: workout.activeCalories,
                                     averageHeartRate: workout.averageHeartRate,
                                     source: .healthKitImport)
          record.segments = [Segment(kind: workout.kind,
                                     startOffset: 0,
                                     durationSeconds: workout.totalSeconds)]
          return record
      }
  }
  ```

- [ ] **Step 6: 테스트 통과를 확인한다**

- [ ] **Step 7: 커밋**

  ```
  ✨ 가져온 워크아웃을 고르는 규칙과 레코드 변환을 만든다
  ```

---

## Task 3: HealthKit 계층

**Files:**

- Create: `iOSApp/Services/WorkoutQueryAnchorStore.swift`
- Create: `iOSApp/Services/HealthKitWorkoutImporter.swift`

**여기부터는 유닛 테스트가 닿지 않는다.** 그래서 규칙을 하나도 두지 않는다 — 쿼리를 돌리고 값을 순수 타입으로 옮기는 일만 한다. 판단은 전부 Task 2 가 가져갔다.

- [ ] **Step 1: 앵커 저장소**

  ```swift
  import Foundation
  import HealthKit

  /// `HKQueryAnchor` 를 `UserDefaults` 에 둔다. 앵커가 없으면 **전체 히스토리**를 읽는다 —
  /// 05 통계가 연도 아카이브라 과거를 자르면 그 화면이 빈 채로 나온다 (스펙 6절).
  ///
  /// 디코딩이 실패하면 nil 로 떨어져 전체를 다시 읽는다. 중복은 플래너가 막으므로
  /// 안전한 폴백이다.
  struct WorkoutQueryAnchorStore {
      private let defaults: UserDefaults
      private let key = "healthKitWorkoutAnchor"

      init(defaults: UserDefaults = .standard) {
          self.defaults = defaults
      }

      func load() -> HKQueryAnchor? {
          guard let data = defaults.data(forKey: key) else { return nil }
          return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
      }

      func save(_ anchor: HKQueryAnchor) {
          guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor,
                                                             requiringSecureCoding: true)
          else { return }
          defaults.set(data, forKey: key)
      }
  }
  ```

- [ ] **Step 2: 앵커드 쿼리**

  ```swift
  import Foundation
  import HealthKit

  /// 앵커드 쿼리 한 번. **규칙을 갖지 않는다** — 매핑 표로 거르고 순수 값으로 옮기는 것까지다.
  ///
  /// 백그라운드 배달(`enableBackgroundDelivery`)을 쓰지 않는다 (D-M4). 컴플리케이션이
  /// 집계 값을 안 보여주므로 앱을 안 열어도 갱신될 이유가 없다.
  struct HealthKitWorkoutImporter {
      struct Batch {
          let workouts: [ImportedWorkout]
          let anchor: HKQueryAnchor?
      }

      private let store = HKHealthStore()

      private var readTypes: Set<HKObjectType> {
          [HKObjectType.workoutType(),
           HKQuantityType(.activeEnergyBurned),
           HKQuantityType(.basalEnergyBurned),
           HKQuantityType(.heartRate)]
      }

      /// **읽기 전용이다** — `toShare` 가 비어 있다. iOS 앱은 HealthKit 에 쓰지 않는다.
      ///
      /// 이미 결정한 사용자에게는 시스템이 시트를 띄우지 않으므로 매번 불러도 무해하다.
      /// **읽기 권한은 허용 여부를 알려주지 않는다** — 거부 상태에서도 에러가 아니라 빈
      /// 결과가 온다 (스펙 7절). 그래서 반환값이 없다.
      func requestAuthorization() async {
          guard HKHealthStore.isHealthDataAvailable() else { return }
          try? await store.requestAuthorization(toShare: [], read: readTypes)
      }

      func fetch(since anchor: HKQueryAnchor?) async -> Batch {
          guard HKHealthStore.isHealthDataAvailable() else {
              return Batch(workouts: [], anchor: nil)
          }

          return await withCheckedContinuation { continuation in
              // updateHandler 를 달지 않는다 — 달면 쿼리가 계속 살아 배치 경계가 흐려진다.
              let query = HKAnchoredObjectQuery(type: .workoutType(),
                                                predicate: nil,
                                                anchor: anchor,
                                                limit: HKObjectQueryNoLimit)
              // 세 번째 인자가 HKDeletedObject 다. **지금은 읽지 않고 버린다** — 건강 앱
              // 삭제 반영은 3개 앱에 걸리는 문제라 YJKit 범위로 옮겼다 (스펙 4절).
              { _, samples, _, newAnchor, _ in
                  let workouts = (samples as? [HKWorkout] ?? []).compactMap(imported(from:))
                  continuation.resume(returning: Batch(workouts: workouts, anchor: newAnchor))
              }
              store.execute(query)
          }
      }

      /// 매핑 표에 없으면 nil 을 돌려 **입구에서 걸러낸다** (D-M5).
      private func imported(from workout: HKWorkout) -> ImportedWorkout? {
          guard let kind = WorkoutTypeMapping.kind(for: workout.workoutActivityType) else { return nil }

          let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
              .sumQuantity()?.doubleValue(for: .kilocalorie())
          // 없으면 없는 대로 둔다. 워크아웃마다 HKStatisticsQuery 를 하나씩 돌리면 첫
          // 동기화에서 쿼리가 수백 개가 되고, 심박은 참고 표시값이다 (스펙 5절 · D5).
          let heartRate = workout.statistics(for: HKQuantityType(.heartRate))?
              .averageQuantity()?.doubleValue(for: .count().unitDivided(by: .minute()))

          return ImportedWorkout(uuid: workout.uuid,
                                 kind: kind,
                                 startedAt: workout.startDate,
                                 endedAt: workout.endDate,
                                 totalSeconds: Int(workout.duration.rounded()),
                                 activeCalories: calories,
                                 averageHeartRate: heartRate)
      }
  }
  ```

- [ ] **Step 3: iOS 빌드를 확인한다**

  ```bash
  xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFit" -destination "id=$IOS" build
  ```

  아직 아무도 부르지 않는 코드다. 여기서 보는 건 **컴파일과 API 시그니처**뿐이다.

- [ ] **Step 4: 커밋**

  ```
  ✨ HealthKit 앵커드 쿼리로 워크아웃 배치를 읽는다
  ```

---

## Task 4: 배선

**Files:**

- Create: `iOSApp/Services/WorkoutSyncCoordinator.swift`
- Modify: `iOSApp/iOSApp.swift`
- Modify: `iOSApp/ContentView.swift`

- [ ] **Step 1: 코디네이터**

  ```swift
  import Combine
  import Foundation
  import SwiftData

  /// 포그라운드 진입과 당겨서 새로고침이 부르는 단 하나의 진입점.
  ///
  /// **쓰기는 `ModelContext` 를 직접 만진다** — `PersistenceService.upsert` 는 건당
  /// `save()` 라 첫 동기화 수백 건에 맞지 않는다 (스펙 6절).
  @MainActor
  final class WorkoutSyncCoordinator: ObservableObject {
      @Published private(set) var isSyncing = false

      private let importer: HealthKitWorkoutImporter
      private let anchors: WorkoutQueryAnchorStore
      private let context: ModelContext

      init(importer: HealthKitWorkoutImporter = HealthKitWorkoutImporter(),
           anchors: WorkoutQueryAnchorStore = WorkoutQueryAnchorStore(),
           context: ModelContext)
      {
          self.importer = importer
          self.anchors = anchors
          self.context = context
      }

      /// **동시에 두 번 돌지 않는다.** 앵커가 경합하면 같은 워크아웃이 두 배치에 나뉘어 들어온다.
      func sync() async {
          guard !isSyncing else { return }
          isSyncing = true
          defer { isSyncing = false }

          await importer.requestAuthorization()
          let batch = await importer.fetch(since: anchors.load())

          do {
              let inserts = WorkoutImportPlanner.inserts(from: batch.workouts,
                                                         existing: try existingUUIDs())
              try apply(inserts)
              // **적용이 끝난 뒤에 앵커를 옮긴다.** 먼저 저장하면 실패한 배치를 영영 다시 못 읽는다.
              if let anchor = batch.anchor { anchors.save(anchor) }
          } catch {
              // 사용자에게 알리는 경로는 03b 기록 목록에서 붙인다 — iOSApp.save(_:) 와 같은 자리다.
              print("[HaruchiFit] HealthKit 동기화 실패 — \(error)")
          }
      }

      /// 이미 가진 키들. **이 집합에 있는 워크아웃은 import 가 건드리지 않는다** (스펙 3절).
      private func existingUUIDs() throws -> Set<UUID> {
          let descriptor = FetchDescriptor<WorkoutRecord>(
              predicate: #Predicate { $0.healthKitUUID != nil }
          )
          return Set(try context.fetch(descriptor).compactMap(\.healthKitUUID))
      }

      /// **한 번만 `save()` 한다** — `PersistenceService.upsert` 는 건당 save 라 첫 동기화
      /// 수백 건에 맞지 않는다 (스펙 6절).
      private func apply(_ inserts: [ImportedWorkout]) throws {
          guard !inserts.isEmpty else { return }
          for workout in inserts {
              context.insert(WorkoutRecord.make(from: workout))
          }
          try context.save()
      }
  }
  ```

- [ ] **Step 2: `iOSApp.swift` 에 주입하고 포그라운드에서 부른다**

  `container` 에서 만든 `ModelContext` 를 코디네이터와 나눠 쓴다. `scenePhase` 가 `.active` 로 들어올 때마다 부른다 (D-M4 — 백그라운드 배달을 안 쓰므로 **이게 유일한 자동 시점**이다).

  ```swift
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var sync: WorkoutSyncCoordinator
  ```

  ```swift
  WindowGroup {
      ContentView()
          .modelContainer(container)
          .environmentObject(sync)
          .onReceive(connectivity.$receivedRecord.compactMap(\.self)) { save($0) }
          .onChange(of: scenePhase) { _, phase in
              guard phase == .active else { return }
              Task { await sync.sync() }
          }
  }
  ```

  ⚠️ `init()` 에서 `store` 와 코디네이터가 **같은 `ModelContext`** 를 보게 한다. 컨텍스트를 두 개 만들면 워치 기록 저장과 import 삽입이 서로의 변경을 못 보고 rollback 이 간섭할 수 있다 (`PersistenceService` 주석 — 단일 컨텍스트 전제).

- [ ] **Step 3: 당겨서 새로고침**

  `ContentView` 의 `NavigationStack` 안쪽 스크롤 컨테이너에 `.refreshable` 을 단다. 잔디 스펙 5절이 이 작업에 예약해 둔 항목이다 — 그전까지는 당겨봐야 로컬 레코드를 다시 접는 것뿐이라 **아무 변화가 없는 컨트롤**이었다.

  ```swift
  @EnvironmentObject private var sync: WorkoutSyncCoordinator
  ```

  ```swift
  .refreshable { await sync.sync() }
  ```

  임시 화면의 레이아웃이 `VStack` + 가로 `ScrollView` 라 세로 당김이 먹지 않는다. **그리드를 세로 `ScrollView` 로 감싸거나 `List` 로 바꾸지 말고**, 바깥에 세로 `ScrollView` 를 하나 두고 거기에 단다 — 이 화면은 Phase 3 #3 이 통째로 대체할 임시 화면이라 구조를 더 손대지 않는다.

- [ ] **Step 4: iOS 빌드 + 시뮬레이터에서 눈으로 본다**

  시뮬레이터에는 건강 데이터가 없어 **유입은 확인할 수 없다.** 여기서 보는 건 세 가지다.

  - 앱이 열릴 때 HealthKit 권한 시트가 뜬다 (읽기 4종)
  - 권한을 거부해도 **크래시 없이** 잔디 화면이 나온다
  - 당겨서 새로고침이 돌고 멈춘다 (스피너가 끝난다)

- [ ] **Step 5: lint · format**

  ```bash
  make fix && make lint && make format
  ```

- [ ] **Step 6: 커밋**

  ```
  ✨ 포그라운드 진입과 당겨서 새로고침에 HealthKit 동기화를 건다
  ```

---

## Task 5: 문서를 맞춘다

**Files:**

- Modify: `docs/specs/shared/2026/2026-09-02-haruchi-fit-architecture.md`
- Modify: `docs/specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md`
- Modify: `docs/specs/shared/2026/2026-09-09-grass-daily-aggregate.md`
- Modify: `TODO.md` (저장소 루트)

- [ ] **Step 1: 아키텍처 4.1 · 4.2 를 확정본으로 고친다**

  4.2 의 *"매핑 표의 최종 목록은 구현 시점에 `HKWorkoutActivityType` 전체를 훑어 확정한다"* 를 **[import 스펙 2절](2026-09-21-healthkit-workout-import.md) 로 가는 링크**로 바꾼다. 예시 목록도 링크로 접는다 — **표를 두 곳에 두면 갈린다.** "한번 정하면 과거 잔디가 달라진다" 는 경고 문장은 남긴다.

  4.1 에는 두 줄을 더한다 — 앵커를 `UserDefaults` 에 둔다는 것, 앵커가 없으면 기간을 자르지 않고 전체 히스토리를 읽는다는 것.

- [ ] **Step 2: 로드맵 Phase 2 와 잔디 스펙 9절**

  로드맵 Phase 2 표의 #2 행을 `~~취소선~~` + 완료(PR 번호)로. 의존 관계 그림의 `HealthKit import` 도 취소선으로. 잔디 스펙 9절 "열린 채로 두는 것" 표의 `.refreshable` 행을 완료로.

- [ ] **Step 3: `TODO.md`**

  하루치 표의 #2 행을 완료로 옮기고, **"집 맥북에서 할 것" 에 실기기 확인 6항목을 넣는다** (스펙 9절). 시뮬레이터로는 판단할 수 없는 것들이다.

  ```
  - [ ] **HealthKit import 실기기 확인** — 건강 앱의 달리기·걷기가 잔디에 들어오는지,
        요가·수영은 안 들어오는지(D-M5), 앱을 껐다 켜도 중복이 안 생기는지(앵커),
        **워치 기록의 시간이 import 로 덮이지 않는지**, 당겨서 새로고침이 새 기록을
        데려오는지, 권한 거부 상태에서도 크래시 없이 열리는지
  ```

  삭제 반영은 **이 문서를 커밋할 때 `## YJKit` 표에 이미 넣었다.** 여기서 또 넣지 않는다.

- [ ] **Step 4: 커밋**

  ```
  📝 HealthKit import 매핑 표 확정을 문서에 반영한다
  ```

---

## Task 6: PR 을 낸다

- [ ] **Step 1: 전체를 한 번 더 돌린다**

  ```bash
  xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
  xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFit" -destination "id=$IOS" build
  xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiComplicationExtension" -destination "id=$WATCH" build
  make lint && make format
  ```

  컴플리케이션까지 보는 이유 — `Shared/` 에 파일을 더했다. **컴플리케이션 타깃에 잘못 붙으면 링커가 깨진다** (2026-09-08 실측). 여기서 걸린다.

- [ ] **Step 2: 푸시하고 PR**

  ```bash
  git push -u origin feat/healthkit-workout-import
  gh pr create --title "✨ 건강 앱의 워크아웃을 가져온다"
  ```

  PR 본문:

  ```markdown
  ## 무엇을

  다른 앱이 건강 앱에 저장한 워크아웃을 매핑 표로 걸러 데려온다. 포그라운드 진입과
  당겨서 새로고침에서 앵커드 쿼리로 증분 동기화한다.

  ## 왜

  매핑 표를 한번 정하면 **사용자의 과거 잔디가 달라진다**(아키텍처 4.2). 잔디를 쓰는
  화면 셋이 Phase 4 에 한꺼번에 나오므로 그 전에 확정한다.

  ## 매핑 표 — 좁게 잡았다

  근력 3종 · 유산소 8종. **`.other` · `.mixedCardio` · `.crossTraining` 을 뺀 것이
  핵심 판단이다** — 사용자가 그 안에 무엇을 넣었는지 앱이 알 수 없고, 오분류가 Phase 4
  비율 차트의 분모로 들어간다. 넓히는 건 쉽고 좁히는 건 어렵다.

  ## 지킨 불변조건

  - `healthKitUUID` 를 이미 가진 레코드는 **건드리지 않는다**(잔디 스펙 6절) — 워치가 잰
    시간(정지 제외)이 HealthKit 값으로 덮이면 과거 잔디가 소급해서 바뀐다
  - 거르는 곳은 **입구 한 군데**다. 집계기는 필터를 갖지 않는다(잔디 스펙 4.5)
  - import 기록은 **세그먼트 1 개**를 갖는다 — 집계 경로를 둘로 가르지 않기 위해

  ## 여기 없는 것 — 삭제 반영

  건강 앱에서 지운 워크아웃은 **앱에서 사라지지 않는다.** 이 동기화는 3개 앱이 같은
  문제를 갖고 있어(HealthKit 워크아웃 ↔ SwiftData 레코드가 UUID 로 묶임) **YJKit 범위로
  옮겼다** (스펙 4절). `HKDeletedObject` 는 읽지 않고 버린다.

  그동안 "건강 앱에서는 지웠는데 잔디에는 남아 있는" 칸이 생긴다. 나중에 삭제를 붙이면
  그 칸이 *사라지는* 쪽이라 **복구할 데이터를 잃지 않는다** — 되돌릴 수 있는 방향의 공백이다.

  ## 검증

  워치 테스트 N개 통과. 시뮬레이터에서 권한 시트·거부 폴백·새로고침 확인.
  **실기기 확인 6항목은 `TODO.md`** — 시뮬레이터에 건강 데이터가 없어 유입 자체를
  볼 수 없다.

  ## 문서

  스펙 신규 1 · 아키텍처 4.1·4.2 갱신 · 로드맵 · 잔디 스펙 9절 · TODO

  🤖 Generated with [Claude Code](https://claude.com/claude-code)
  ```

- [ ] **Step 3: CI 통과 후 머지**

  ```bash
  gh pr merge <n> --merge --delete-branch
  ```

- [ ] **Step 4: 워크트리 정리**

  실기기 확인 6항목이 남아 있으면 **유지한다.** 다 끝난 뒤에 지우고, 지울 때 DerivedData 도 같이 지운다.

  ```bash
  git worktree remove ../yj-apps-worktrees/healthkit-workout-import
  make dd-prune        # 고아 목록만
  make dd-prune-apply  # 실제로 삭제
  ```

---

## 나중으로 미룬 것 (스펙 10절)

| 항목 | 언제 |
|---|---|
| **건강 앱 삭제 반영** | **YJKit 범위** — 3개 앱이 같은 문제를 갖는다 (스펙 4절) |
| 매핑 표 확장 | 실사용 데이터를 보고. **앵커 초기화를 함께** |
| 동기화 실패 알림 UI | Phase 3 #4 (03b 기록 목록) |
| 평균 심박 보강 쿼리 | 실기기에서 `statistics(for:)` 가 자주 nil 이면 |
| 백그라운드 배달 | iOS 홈 화면 위젯을 도입하면 (D-M4) |
| import 기록의 부위 태깅 | Phase 3 #5 (04 상세)에서 사용자가 손으로 |
| 01 온보딩 권한 화면 | Phase 5 #12 — 여기서는 경로만 만든다 |
