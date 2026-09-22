# 기록 삭제 시 건강 앱 워크아웃도 삭제 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ralli 기록 탭에서 세션을 밀어 삭제하면 건강 앱의 해당 테니스 워크아웃도 함께 사라진다. 지금은 앱 기록만 지워지고 건강 앱에는 그대로 남아 "지웠는데 왜 아직 있지?"가 된다.

**Architecture:** 삭제 실행체를 YJKit `WorkoutCore` 에 새로 둔다 — 지울 대상인 `healthKitUUID` 를 만드는 곳이 바로 거기(`WorkoutResult.healthKitUUID` ← `WorkoutSessionService.finishWorkout()`)이고, `WorkoutCore` 는 이미 `HealthKit` 을 import 하며 워치 전용부만 `#if os(watchOS)` 로 막혀 있어 iOS 에서 그대로 쓸 수 있다. 앱 레이어는 `HistoryViewModel.delete(_:)` 한 곳에서 `session.record?.healthKitUUID` 를 꺼내 넘긴다. 목록 모드와 캘린더 모드가 같은 `SessionList` 를 거쳐 같은 `delete(_:)` 로 합류하므로 진입점은 하나다.

**Tech Stack:** HealthKit `deleteObjects(of:predicate:)` · SwiftData · SwiftUI `confirmationDialog`

**Spec:** 별도 스펙 없음 — 2026-09-21 대화에서 확정. 아래 §결정 사항.

**Scope:** 문서는 Ralli가 소유한다 (`Apps/TennisCounter/docs/plans/shared/`). 구현은 공용
YJKit `WorkoutCore`의 삭제 실행체와 Ralli iOS 기록 화면·저장소 배선을 함께 건드리므로
플랫폼 분류가 `shared`다. YJKit 단독 로드맵이 아니다.

## 현재 동작 (확인 완료)

- 기록 탭은 SwiftData 만 읽는다. HealthKit 을 조회하는 코드가 앱 전체에 없다.
- `WorkoutSessionRecord.healthKitUUID` 는 **저장만 되고 읽히는 곳이 없다** — 워치 → 메시지 → SwiftData 까지 배관은 이미 깔려 있다.
- 밀어서 삭제는 이미 구현돼 있다 (`SessionList.swift:21` `.swipeActions` → 확인 다이얼로그 → `HistoryViewModel.delete(_:)`).
- iOS 타깃에 HealthKit entitlement 와 `NSHealth*UsageDescription` 이 **이미 있다.** 요청 코드만 없다.

## 결정 사항 (2026-09-21)

| 논점 | 결정 | 이유 |
|---|---|---|
| 배치 | **YJKit `WorkoutCore`** | `healthKitUUID` 생산자와 같은 타깃. 새 프로덕트를 만들면 3앱 6타깃 링크 표를 건드려야 하는데 얻는 게 없다. "UUID로 워크아웃 하나 삭제"는 종목을 모르므로 "코어는 도메인을 모른다" 규약에 안 걸린다 |
| 삭제 API | **`deleteObjects(of:predicate:)`** — 조회 없이 한 번에 | 조회를 끼우면 읽기 권한까지 얽힌다. 이 API 는 쓰기 권한 하나로 끝나고 호출도 1회 |
| 요청 권한 | **`workoutType()` share 1종만.** read 없음 | 삭제에 필요한 건 쓰기 권한뿐 |
| 권한 요청 시점 | **첫 삭제 시** (앱 시작 아님) | 맥락 없이 앱 켜자마자 건강 권한을 묻는 것보다 이유가 분명하다 |
| 실패·권한 거부 | 앱 기록은 지우고 **"건강 앱 기록은 삭제하지 못했습니다" 알럿 1회** | 조용히 넘기면 지금 고치려는 문제를 그대로 재현한다 |
| `healthKitUUID` nil (구버전) | 앱 기록만 삭제, **조용히**. 알럿 없음 | 애초에 건강 앱에 연결된 적이 없는 기록이다. **시각 기반 매칭은 하지 않는다** — 남의 앱 워크아웃을 지울 위험 |
| 토글 여부 | **없음. 항상 함께 삭제** | 토글은 상태·문구·테스트를 늘리면서 "지웠는데 남음"을 고치려는 목적과 어긋난다 |
| 삭제 순서 | **SwiftData 먼저, HealthKit 은 best-effort** | HK 를 먼저 하면 권한 시트 동안 UI 가 멈추고, 실패 시 앱 기록까지 안 지워져 더 나쁘다. 앱 기록 삭제는 사용자가 확실히 원한 것 |
| CloudKit 전파 | 별도 처리 없음 | 전파된 삭제는 `delete(_:)` 를 안 거치고, 건강 데이터도 iCloud 동기화라 그 기기에선 이미 지워져 있다 |
| 건강 앱 → Ralli 역방향 | **감지·동기화하지 않음.** Ralli 기록·운동 수치·`healthKitUUID` 를 모두 유지 | Ralli가 경기 기록의 원본이고 건강 앱 워크아웃은 부가 기록이다. 건강 앱에서 운동만 정리한 행위로 점수·세트·CloudKit 기록까지 지우지 않는다. 읽기 권한·옵저버·백그라운드 전달도 불필요 |
| 사용 권한 문구 | **iOS 타깃 것만 수정** | 현재 "Ralli saves your tennis workout to Apple Health." 인데 폰은 저장이 아니라 삭제를 한다. 타깃별 빌드 세팅이라 워치 문구는 그대로 둘 수 있다 |
| GolfCounter | **범위 밖** | `healthKitUUID` 자체가 없고 iOS 타깃이 `WorkoutCore` 를 링크하지 않는다. UUID 배관부터 깔아야 하는 별도 작업 |

## 역방향 정책 — 건강 앱에서 먼저 지운 경우 (2026-09-22 확정)

건강 앱에서 워크아웃을 먼저 지워도 Ralli 쪽은 **아무것도 변경하지 않는다.**

- `HKObserverQuery`·`HKAnchoredObjectQuery`·`HKDeletedObject` 기반 삭제 감지를 구현하지 않는다.
- 워크아웃 읽기 권한과 HealthKit 백그라운드 전달을 추가하지 않는다.
- Ralli의 경기·세션 기록, 시간·칼로리·심박 스냅샷, `healthKitUUID` 를 모두 유지한다.
  `healthKitUUID` 는 실시간 연결이 아니라 HealthKit 객체를 찾는 식별자이므로, 대상이 먼저
  삭제되어도 Ralli에 저장된 수치에 영향을 주지 않는다.
- 나중에 사용자가 Ralli에서 같은 세션을 삭제하면 #10의 UUID predicate 삭제를 그대로
  호출한다. API가 오류 없이 `deletedObjectCount == 0`을 돌려준 경우는 "이미 없음"으로 보고
  성공 처리한다.
- 나중에 건강 앱 존재 여부를 UI에 보여줄 필요가 생기면 UUID를 비우지 말고 별도
  상태를 추가하는 독립 플랜으로 다룬다.

**Apple 공식 참조**

- [`HKHealthStore.deleteObjects(of:predicate:withCompletion:)`](https://developer.apple.com/documentation/healthkit/hkhealthstore/deleteobjects%28of%3Apredicate%3Awithcompletion%3A%29)
  — 자신이 저장한 객체만 삭제할 수 있고, async API는 삭제된 객체 개수를 돌려준다.
- [`HKQuery.predicateForObject(with:)`](https://developer.apple.com/documentation/healthkit/hkquery/predicateforobject%28with%3A%29)
  — HealthKit 객체의 UUID로 한 개를 지정하는 predicate를 만든다.
- [`HKObserverQuery`](https://developer.apple.com/documentation/healthkit/hkobserverquery) ·
  [`HKDeletedObject`](https://developer.apple.com/documentation/healthkit/hkdeletedobject) — 외부 삭제를 감지할 때
  필요한 API이지만, 이 플랜의 역방향 정책에서는 사용하지 않는다.

## 미검증 가정 — 실패 시 트랙이 갈린다

**이 워크아웃을 저장한 건 워치 앱(`com.yj.TennisCounter.watchkitapp`)이고, 지우려는 건 폰 앱(`com.yj.TennisCounter`)이다.** HealthKit 은 권한과 별개로 "자기 앱이 저장한 샘플만 지울 수 있다"는 제약을 둔다. 폰과 워치가 같은 소스로 취급되는지는 **실기기로만 확인된다** — 스파이크를 건너뛰기로 했으므로 "지울 수 있다"를 가정하고 간다.

**참고 데이터 — 반쪽짜리 선례.** 하루치 핏 W2 실기기 검증에서 `HKHealthStore.delete` 가 **워치에서** 통과했다 (TODO.md "W2 실기기 검증 4항목", 워크아웃 버리기 → 건강 앱에서도 사라짐). 삭제 API 자체와 워치의 자기 기록 삭제는 증명됐지만, **폰이 워치 저장분을 지우는 경로는 여전히 미검증이다** — 소스가 다르다.

가정이 틀리면 §실기기 확인에서 **삭제가 매번 실패 알럿으로 드러난다.** 그때는 폰이 워치로 삭제 명령을 보내는 별도 트랙으로 전환한다 (`ConnectivityMessages` 에 메시지 타입 추가 + 워치 수신 처리 + 워치 미도달 시 큐잉). 이 플랜의 Task 1·2 는 그 경우에도 그대로 쓰인다 — 실행체만 워치로 옮겨 간다.

## Global Constraints

- **패키지 소스를 고치면 재빌드 시 즉시 반영된다.** 푸시도 local override 도 필요 없다.
- 워치 코드는 건드리지 않는다. `WorkoutSessionService` 의 기존 `requestAuthorization()` 도 그대로 둔다 — 그건 `WorkoutConfiguration` 을 요구하는 인스턴스 메서드라 폰에서 삭제만 하는 맥락에 안 맞는다.
- `NSHealthShareUsageDescription` 은 손대지 않는다 (읽기를 안 한다).
- `WorkoutDeleting` 프로토콜을 노출해 앱 레이어 테스트에서 페이크를 끼울 수 있게 한다. `HKHealthStore` 는 SPM 테스트에서 다룰 수 없다.
- 브랜치 + PR. 커밋은 YJKit(`✨`) / 앱(`✨`) / 문서(`📝`) 로 나눈다.

**빌드·검증 명령** (루트에서)

```bash
make kit-test
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test
make lint && make format
```

## File Structure

| 파일 | 상태 | 책임 |
|---|---|---|
| `Packages/YJKit/Sources/WorkoutCore/WorkoutDeletionService.swift` | 신규 | `WorkoutDeleting` 프로토콜 + HealthKit 구현체. 권한 요청 → `deleteObjects` |
| `Packages/YJKit/Tests/WorkoutCoreTests/WorkoutDeletionServiceTests.swift` | 신규 | store 없이 되는 것만 (빈 입력 조기 반환, 결과 매핑) |
| `Apps/TennisCounter/iOSApp/Features/History/HistoryViewModel.swift` | 수정 | `delete(_:)` 에서 UUID 수집 → deleter 호출. 실패 상태 `@Published` |
| `Apps/TennisCounter/iOSApp/Features/History/HistoryView.swift` | 수정 | 확인 문구 교체 + 실패 알럿 |
| `Apps/TennisCounter/iOSApp/Localizable.xcstrings` | 수정 | 확인 메시지 수정 + 실패 알럿 문구 신규 (en/ko) |
| `Apps/TennisCounter/iOSApp/InfoPlist.xcstrings` | 수정 | `NSHealthUpdateUsageDescription` 을 삭제 맥락으로 |
| `Apps/TennisCounter/iosTests/History/HealthKitDeletionTests.swift` | 신규 | 페이크 deleter 로 호출 규약 검증 |
| `Apps/TennisCounter/ReadMe.md` | 수정 | 권한 표 (**미확정 — §후속 참고**) |

`SessionPersistenceService` 는 **손대지 않는다.** `MatchSessionGroup` 이 이미 `record: WorkoutSessionRecord?` 를 들고 있어 `session.record?.healthKitUUID` 로 바로 꺼낼 수 있다.

---

### Task 1: WorkoutCore 에 삭제 서비스 추가

**Files:**
- Create: `Packages/YJKit/Sources/WorkoutCore/WorkoutDeletionService.swift`

- [ ] **Step 1: 결과 타입과 프로토콜**

```swift
public enum WorkoutDeletionOutcome: Equatable {
    /// 지울 대상이 없었다. 구버전 기록처럼 healthKitUUID 가 없는 경우 — 사용자에게 알리지 않는다.
    case nothingToDelete
    case deleted
    case notAuthorized
    case failed
}

public protocol WorkoutDeleting: Sendable {
    func deleteWorkouts(uuids: [UUID]) async -> WorkoutDeletionOutcome
}
```

`notAuthorized` 와 `failed` 를 나누는 이유 — 쓰기 권한은 `authorizationStatus(for:)` 가 `sharingDenied` / `sharingAuthorized` 를 정직하게 돌려준다 (읽기 권한과 달리 프라이버시 은폐가 없다). 알럿 문구를 나눌 수 있다.

- [ ] **Step 2: 구현체**

`WorkoutDeletionService: WorkoutDeleting`. 내부에 `HKHealthStore` 하나.

1. `uuids` 가 비면 즉시 `.nothingToDelete`
2. `HKHealthStore.isHealthDataAvailable()` 아니면 `.failed`
3. `requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])`
4. `authorizationStatus(for: .workoutType())` 가 `.sharingAuthorized` 아니면 `.notAuthorized`
5. UUID 마다 `deleteObjects(of: .workoutType(), predicate: HKQuery.predicateForObject(with: uuid))`
6. 전부 성공하면 `.deleted`, 하나라도 던지면 `.failed`

**주의:** 이미 지워진 워크아웃에 `deleteObjects` 를 부르면 삭제 개수가 0일 수 있다.
호출이 throw 하지 않았다면 `deletedObjectCount == 0`도 실패로 취급하지 않는다 — 건강 앱에서
먼저 지웠거나 CloudKit 전파·재시도에서 정상적으로 발생할 수 있다.

- [ ] **Step 3: 빌드**

```bash
make kit-test
```

---

### Task 2: YJKit 테스트

**Files:**
- Create: `Packages/YJKit/Tests/WorkoutCoreTests/WorkoutDeletionServiceTests.swift`

- [ ] **Step 1: store 없이 되는 것만**

- 빈 배열 → `.nothingToDelete` (HealthKit 을 아예 안 건드리는지)
- `WorkoutDeletionOutcome` 의 `Equatable` 동작

HealthKit 권한이 얽힌 경로는 유닛 테스트로 못 간다. 실제 검증은 §실기기 확인이 맡는다.

- [ ] **Step 2:** `make kit-test` 통과 확인

---

### Task 3: HistoryViewModel 연결

**Files:**
- Modify: `Apps/TennisCounter/iOSApp/Features/History/HistoryViewModel.swift`

- [ ] **Step 1: deleter 주입**

`private let workoutDeleter: WorkoutDeleting` 를 생성자 인자로 받되 기본값을 `WorkoutDeletionService()` 로 둔다. 테스트가 페이크를 끼운다. `import WorkoutCore` 추가.

- [ ] **Step 2: 실패 상태 노출**

`@Published var deletionFailure: WorkoutDeletionOutcome?` — `.notAuthorized` / `.failed` 일 때만 채운다. View 가 알럿을 띄우고 nil 로 되돌린다.

- [ ] **Step 3: `delete(_:)` 수정**

`delete(_:)` **맨 위에서** `let healthKitUUID = session.record?.healthKitUUID` 를 먼저 잡는다 — SwiftData 를 지운 뒤에는 못 읽는다.

기존 SwiftData 삭제와 배열 정리는 **그대로 두고**, 마지막에 HK 삭제를 `Task { @MainActor in ... }` 로 띄운다. 결과가 `.notAuthorized` / `.failed` 면 `deletionFailure` 에 넣는다. `.nothingToDelete` / `.deleted` 는 무시.

- [ ] **Step 4: 주석 갱신**

`delete(_:)` 위 주석에 건강 앱 워크아웃도 함께 지운다는 사실을 한 줄 추가한다. 지금 주석은 CloudKit 전파만 말한다.

---

### Task 4: 확인 문구와 실패 알럿

**Files:**
- Modify: `Apps/TennisCounter/iOSApp/Features/History/HistoryView.swift`
- Modify: `Apps/TennisCounter/iOSApp/Localizable.xcstrings`

- [ ] **Step 1: 확인 다이얼로그 메시지**

`history_delete_confirm_message` 에 건강 앱 워크아웃도 지워진다는 사실을 넣는다 (en/ko). 삭제 **전에** 알려야 한다.

- [ ] **Step 2: 실패 알럿**

`.confirmationDialog` 아래에 `.alert` 을 붙인다. `viewModel.deletionFailure` 바인딩.

문구 신규 2종 (en/ko):
- `history_delete_health_denied` — 권한 거부. "건강 앱 접근 권한이 없어 운동 기록은 삭제하지 못했습니다. 설정 > 개인정보 보호 > 건강에서 허용할 수 있습니다."
- `history_delete_health_failed` — 그 외 실패. "건강 앱의 운동 기록은 삭제하지 못했습니다. 건강 앱에서 직접 삭제해 주세요."

**목록 모드와 캘린더 모드 양쪽에서 떠야 한다.** 알럿을 `Group` 바깥(`.navigationTitle` 이 붙은 레벨)에 달면 한 번으로 둘 다 덮인다.

---

### Task 5: 사용 권한 문구

**Files:**
- Modify: `Apps/TennisCounter/iOSApp/InfoPlist.xcstrings`

- [ ] **Step 1: `NSHealthUpdateUsageDescription` 수정 (en/ko)**

현재 "Ralli saves your tennis workout to Apple Health." 는 폰 맥락과 맞지 않는다. 사용자는 삭제 버튼을 누른 직후 이 시트를 본다.

제안: "Ralli removes deleted matches from your Apple Health workouts." / "Ralli가 삭제한 경기의 운동 기록을 건강 앱에서 함께 지웁니다."

**워치 쪽(`WatchApp/InfoPlist.xcstrings`)은 건드리지 않는다.** 타깃별 빌드 세팅이라 서로 독립이다.

- [ ] **Step 2:** iOS 스킴 빌드로 plist 생성 확인

---

### Task 6: 앱 레이어 테스트

**Files:**
- Create: `Apps/TennisCounter/iosTests/History/HealthKitDeletionTests.swift`

- [ ] **Step 1: 페이크 deleter**

`WorkoutDeleting` 을 구현하고 받은 `uuids` 를 기록하는 스파이. 반환값을 테스트가 지정한다.

- [ ] **Step 2: 케이스**

- [ ] `record?.healthKitUUID` 가 있으면 그 UUID 가 deleter 에 전달된다
- [ ] `healthKitUUID` 가 nil 이면 **deleter 를 아예 부르지 않는다** (또는 빈 배열로 불러 `.nothingToDelete`)
- [ ] 한 세션에 경기가 여러 개여도 UUID 는 1개만 넘어간다
- [ ] deleter 가 `.failed` 를 줘도 **SwiftData 삭제는 그대로 완료된다** — 순서 결정의 핵심
- [ ] `.failed` / `.notAuthorized` 면 `deletionFailure` 가 채워진다
- [ ] `.deleted` / `.nothingToDelete` 면 `deletionFailure` 가 nil 로 남는다

---

### Task 7: 검증

- [ ] `make kit-test`
- [ ] `xcodebuild -workspace YJApps.xcworkspace -scheme "TennisCounter" -destination "id=$IOS" test`
- [ ] `make lint && make format`

## 실기기 확인 — 시뮬레이터로 안 되는 것들

건강 권한 시트와 실제 워크아웃 삭제는 실기기에서만 제대로 확인된다.

**핵심 가정 검증 (여기서 트랙이 갈린다)**
- [ ] 워치로 경기 → 종료 → 건강 앱에 워크아웃이 생긴 것 확인
- [ ] **폰 기록 탭에서 그 세션 삭제 → 건강 앱에서도 사라지는가**
- [ ] 사라지지 않고 실패 알럿이 뜨면 → §미검증 가정의 워치 명령 트랙으로 전환. 이 문서에 결과를 기록한다

**권한 흐름**
- [ ] 첫 삭제에서 권한 시트가 뜬다. 토글이 "운동" 하나만 보인다
- [ ] 시트 문구가 Task 5 에서 바꾼 삭제 맥락 문구다 (저장 문구가 아니다)
- [ ] 허용 → 삭제 성공, 알럿 없음
- [ ] 거부 → 앱 기록은 지워지고 `history_delete_health_denied` 알럿
- [ ] 두 번째 삭제부터는 시트가 안 뜬다

**경계**
- [ ] 구버전 기록(`healthKitUUID` nil) 삭제 → 조용히 앱 기록만. 알럿 없음, 권한 시트도 안 뜸
- [ ] 캘린더 모드 하단 목록에서 삭제 → 목록 모드와 동일하게 동작 + 알럿도 뜸
- [ ] 경기 여러 개인 세션 삭제 → 건강 앱 워크아웃 1개만 사라짐
- [ ] 경기 없이 운동만 한 세션 삭제 → 정상 동작
- [ ] 기기 2대 CloudKit — A 에서 삭제 → B 의 앱 기록도 사라지고, B 의 건강 앱도 이미 비어 있음

**결과 기록** — 가정이 틀렸거나 문구 조정이 필요했으면 이 문서 §결정 사항에 한 줄 추가한다.

## 후속 (이번 작업에 넣을지 미확정)

- **ReadMe 권한 표** — 어느 기기에서 / 언제 / 어떤 타입을 / 왜 요청하는지. 현재 Ralli 의 권한 요청은 워치 HealthKit 1개뿐이고(`WorkoutSessionViewModel.swift:183`, 워크아웃 시작 시), 이번 변경으로 폰에 1개가 추가돼 총 2개가 된다. `aps-environment` 엔타이틀먼트는 있으나 알림 권한 요청 코드는 없어 시트가 뜨지 않는다. **사용자 판단 대기 중** — 이번 커밋에 포함할지, 3앱을 한꺼번에 정리하는 별도 작업으로 뺄지.
- **HaruchiFit 적용** — `WorkoutRecord.healthKitUUID` 를 이미 갖고 있고 iOS 타깃이 `WorkoutCore` 를 이미 링크한다. 삭제 기능 자체가 아직 없어서 그게 생길 때 `WorkoutDeleting` 을 그대로 쓴다.
- **GolfCounter 적용** — `healthKitUUID` 배관부터 깔아야 한다. 삭제 UI 는 이미 있다 (`HistoryView.swift:54`).

## Self-Review

- 결정 12건 → 배치(Architecture), 삭제 API·권한(Task 1 Step 2), 요청 시점(Task 3), 실패 처리(Task 3 Step 2 + Task 4 Step 2), nil UUID(Task 6), 토글 없음(Task 4 Step 1), 순서(Task 3 Step 3 + Task 6), CloudKit(실기기 경계), 역방향 미감지(§역방향 정책), 문구(Task 5), Golf 제외(후속) ✅
- 미검증 가정 명시 + 실패 시 전환 트랙 + 확인 항목 연결 ✅
- `SessionPersistenceService` 불필요 판단 근거 기재 ✅
- 미확정 항목(ReadMe)을 File Structure 와 후속 양쪽에 표시 ✅
