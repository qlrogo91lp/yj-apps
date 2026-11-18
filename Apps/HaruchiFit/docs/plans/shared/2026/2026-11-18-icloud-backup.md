# 하루치 iCloud 백업 구현 플랜

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 앱을 지웠다 다시 깔거나 기기를 바꿔도 구간(근력·유산소) · 부위 · 메모 · 수동 기록이 iCloud 에서 돌아오게 한다.

**Architecture:** 기존 SwiftData 저장소에 CloudKit 미러링을 켠다 (`PersistenceContainerFactory` 는 이미 `.automatic` 을 시도한다 — 엔타이틀먼트만 없다).
재설치 직후 HealthKit 전체 재가져오기가 만든 임시 기록과 iCloud 에서 내려온 원래 기록이 같은 `healthKitUUID` 로 겹치므로,
`Shared/Persistence` 의 중복 정리 함수가 원래 기록을 남기고 임시 기록을 지운다. 정리는 포그라운드 동기화 끝과 원격 변경 알림에서 돈다.

**Tech Stack:** SwiftData + CloudKit(private DB) · Swift Testing · iOS 17

**Spec:** 별도 스펙 없음 — 2026-11-18 대화에서 확정한 설계를 아래 "결정" 에 옮겼다.
미뤘던 근거는 `docs/plans/shared/2026/2026-10-19-release-checklist.md` 1절 결정 1.

**Linear:** [YJ-48](https://linear.app/yj-workpace/issue/YJ-48) — 스티커 복사 단축어와 같은 다음 업데이트로 함께 심사받는다.

## 결정

- **목적은 백업이다.** 재설치 · 기기 변경 때 복원. 여러 기기 동시 사용은 범위 밖 — 기기 간 편집 충돌은 다루지 않는다
- **방식 A — SwiftData + CloudKit 자동 동기화.** B(iCloud Drive JSON 백업)는 복원 화면 · 백업 시점을 직접 만들어야 해 같은 결과에 품이 더 든다
- **중복이면 원래 기록이 이긴다.** 같은 `healthKitUUID` 가 둘 이상이면 아래 순서로 하나를 남긴다
  1. `source != .healthKitImport` (워치 · 수동)
  2. 주석 점수가 높은 쪽 — 구간 수 + 메모 있음(1) + 부위 수
  3. 동점이면 아무거나 하나 (내용이 같다)
  - 남는 쪽의 메모 · 부위가 비어 있고 지워지는 쪽에 있으면 옮겨 담는다 — 복원 전 몇 분 사이에 임시 기록에 단 메모를 잃지 않게
- **앱 안 설정을 두지 않는다.** 아이폰 설정 > iCloud 의 앱별 스위치를 따른다. 꺼져 있으면 지금처럼 로컬 저장 (팩토리 폴백)
- **복원 중 표시를 두지 않는다.** `@Query` 화면이 들어오는 대로 갱신된다
- **원격 알림 백그라운드 모드는 넣지 않는다.** Ralli · 골프와 같다 — 백업은 앱을 켠 동안의 가져오기로 충분하다
- **출시는 1.0.1 다음 버전.** YJ-48(스티커 단축어)의 하루치 Xcode 실기기 확인을 이 작업보다 먼저 끝낸다 — 이 작업 뒤로는 본인 아이폰에 TestFlight 로만 설치한다

## YJ-48 단축어와의 관계

같은 업데이트로 나가는 스티커 복사 단축어(`docs/plans/2026/2026-11-18-last-workout-sticker-shortcut.md`)와 **다른 워크트리에서 동시에** 진행한다.

- **겹치는 파일은 `iOSApp/iOSApp.swift` 하나.** 단축어 플랜이 컨테이너를 `HaruchiFitApp.modelContainer`(static)로 옮긴다. 이 플랜은 그 선언 위 주석만 고친다 — 늦게 머지하는 쪽이 주석을 옮긴다
- **단축어를 먼저 머지한다.** 단축어의 하루치 실기기 확인은 CloudKit 이 없는 빌드를 Xcode 로 설치해 한다. 이 브랜치를 main 에 넣기 전에 끝나야 한다
- 이 브랜치는 단축어 머지 뒤 main 을 받아 충돌을 정리하고 머지한다. TestFlight 확인(작업 4)은 두 작업이 모두 들어간 빌드 하나로 한다
- 복원 중 몇 분 동안 단축어를 실행하면 겹친 임시 기록(근력 한 구간)을 복사할 수 있다. 날짜 · 시간 · 칼로리는 같아 막지 않는다

## Global Constraints

- 최소 버전 iOS 17 · watchOS 10 그대로
- CloudKit 컨테이너 `iCloud.com.yj.HaruchiFit` — iOS 앱 타깃(`HaruchiFit.entitlements`)에만. 워치 · 컴플리케이션은 SwiftData 를 쓰지 않는다
- 모델(`WorkoutRecord` · `Segment`) 필드를 추가 · 삭제 · 이름 변경하지 않는다 — 실서비스 스키마 배포 뒤에는 추가만 된다
- 새 화면 문자열 없음 (String Catalog 변경 없음)
- 테스트는 Swift Testing, `watchosTests/` 에 둔다 (iOS 테스트 타깃이 없다 — `Shared/` 를 워치 테스트가 검증하는 기존 방식)
- 본인 아이폰(실제 기록이 있는 기기)에는 **TestFlight 로만** 설치한다. Xcode Debug 빌드는 CloudKit Development 환경을 쓴다

## Review Focus

1. **원격 변경 알림이 오지 않을 때** — SwiftData 가 `.NSPersistentStoreRemoteChange` 를 내보내지 않으면 중복이 다음 포그라운드 진입까지 남는다.
   포그라운드 동기화 끝의 정리가 안전망이다. TestFlight 확인에서 "앱을 켠 채로 중복이 사라지는지" 를 본다 (작업 4)
2. **상세 시트가 띄운 기록을 정리가 지울 때** — 떠 있는 시트가 지워진 모델을 읽으면 크래시한다 (`RecordDetailSheet` 주석).
   정리 함수가 보호 ID 를 받아 그 기록이 낀 묶음을 통째로 건너뛴다 → 테스트 `removeDuplicatesSkipsGroupContainingProtectedRecord` (작업 1)
3. **HealthKit 가져오기와 정리가 겹칠 때** — 원격 알림이 `sync()` 도중에 오면 반쯤 들어간 배치를 정리할 수 있다.
   `isSyncing` 중에는 원격 트리거 정리를 건너뛰고 `sync()` 끝의 정리에 맡긴다 (작업 2)
4. **iCloud 로그아웃 · 앱별 스위치 끔** — 팩토리가 로컬로 폴백한다. 정리는 저장소와 무관하게 같은 결과여야 한다 (작업 1 테스트가 로컬 인메모리 저장소로 돈다)
5. **주석 없는 동일 기록 쌍** — 둘 다 HealthKit 가져오기 · 주석 없음이면 정확히 하나만 남아야 한다 → `removeDuplicatesTieLeavesExactlyOne` (작업 1)

---

### 작업 1: 중복 정리 함수

**Files:**
- Create: `Shared/Persistence/ModelContext+DuplicateCleanup.swift`
- Test: `watchosTests/Models/DuplicateCleanupTests.swift`

**Interfaces:**
- Produces: `extension ModelContext { @discardableResult func removeDuplicateWorkouts(protecting protected: Set<PersistentIdentifier> = []) throws -> Int }`
  — 지운 기록 수를 돌려준다. `healthKitUUID == nil`(수동 기록)은 건드리지 않는다. 묶음 중 하나라도 `protected` 에 있으면 그 묶음은 건너뛴다.
  지울 것이 있으면 `save()` 한 번, 실패하면 `rollback()` 후 다시 던진다.

- [ ] **Step 1: 실패하는 테스트를 쓴다.** `GrassFixture.makeContext()` 와 `WorkoutRecord(...)` · `GrassFixture.record(...)` 로 기록을 만든다. 같은 `healthKitUUID` 를 직접 대입한다.

| 테스트 | 준비 | 기대 |
|---|---|---|
| `removeDuplicatesKeepsWatchRecordOverHealthKitImport` | 같은 UUID: `.watch` + 구간 2개(근력 · 유산소) / `.healthKitImport` + 근력 1개 | 반환 1, 남은 기록의 `source == .watch`, 구간 종류 `[.strength, .cardio]` |
| `removeDuplicatesPrefersAnnotatedRecordWhenSourcesMatch` | 같은 UUID 둘 다 `.healthKitImport`, 한쪽만 `memo = "하체"` · `bodyPartsRaw = ["legs"]` | 남은 기록의 메모 `"하체"` |
| `removeDuplicatesCopiesMemoAndBodyPartsFromRemovedRecord` | `.watch`(메모 · 부위 없음) + `.healthKitImport`(메모 `"복원 전 메모"`, 부위 `["chest"]`) | 남은 `.watch` 기록의 메모 `"복원 전 메모"`, `bodyPartsRaw == ["chest"]` |
| `removeDuplicatesKeepsKeeperMemoWhenBothHaveOne` | `.watch` 메모 `"원래"` + `.healthKitImport` 메모 `"임시"` | 메모 `"원래"` |
| `removeDuplicatesLeavesManualRecordsAlone` | `healthKitUUID == nil` 인 `.manual` 기록 둘 (같은 시각) | 반환 0, 기록 2개 |
| `removeDuplicatesLeavesUniqueRecordsAlone` | UUID 가 모두 다른 기록 3개 | 반환 0, 기록 3개 |
| `removeDuplicatesDeletesSegmentsOfRemovedRecord` | 첫 행과 같은 준비 | `Segment` 전체 개수 2 |
| `removeDuplicatesTieLeavesExactlyOne` | 같은 UUID, 둘 다 `.healthKitImport` · 주석 없음 · 근력 1개 | 반환 1, 그 UUID 기록 1개 |
| `removeDuplicatesSkipsGroupContainingProtectedRecord` | 첫 행 준비에서 `.healthKitImport` 쪽 ID 를 `protecting:` 에 넘김 | 반환 0, 기록 2개 |

- [ ] **Step 2: 실패를 확인한다.**
  Run: `xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFitWatchTests -destination "id=$WATCH" test -only-testing:HaruchiFitWatchTests/DuplicateCleanupTests`
  Expected: 컴파일 실패 — `removeDuplicateWorkouts` 없음
- [ ] **Step 3: `removeDuplicateWorkouts(protecting:)` 를 구현한다.** `healthKitUUID != nil` 전체를 한 번 fetch → UUID 로 묶기 → 결정의 순서로 남길 하나를 고르고 나머지를 `delete` (구간은 cascade).
- [ ] **Step 4: 통과를 확인한다.** 같은 명령, 9개 PASS. 이어서 스위트 전체(`-only-testing` 없이)도 PASS.
- [ ] **Step 5: 커밋** — `✨ feat: 같은 운동이 겹친 기록을 정리한다`

### 작업 2: 정리를 동기화와 원격 변경에 잇는다

**Files:**
- Modify: `iOSApp/Services/WorkoutSyncCoordinator.swift`
- Modify: `iOSApp/Features/Records/Detail/RecordDetailSheet.swift`

**Interfaces:**
- Consumes: 작업 1 의 `removeDuplicateWorkouts(protecting:)`
- Produces: `WorkoutSyncCoordinator` 에
  - `var protectedRecordID: PersistentIdentifier?` — 상세 시트가 띄운 기록. 시트가 열릴 때 넣고 닫힐 때 nil
  - `func cleanUpDuplicates()` — `protectedRecordID` 를 보호 집합으로 넘겨 정리. 실패는 `print` 로만 남긴다 (사용자에게 알릴 일이 아니다 — 다음 기회에 다시 돈다)

- [ ] **Step 1:** `sync()` 에서 `apply` 와 앵커 저장 뒤에 `cleanUpDuplicates()` 를 부른다.
- [ ] **Step 2:** init 에서 `NotificationCenter.default` 의 `.NSPersistentStoreRemoteChange`(`import CoreData`)를 구독한다. 1초 debounce, 메인 액터에서
  `isSyncing` 이면 건너뛰고 아니면 `cleanUpDuplicates()`. 구독은 `AnyCancellable` 로 보관한다.
- [ ] **Step 3:** `RecordDetailSheetModifier` 가 `@EnvironmentObject` 로 `WorkoutSyncCoordinator` 를 받아, 시트가 띄운 기록의 `persistentModelID` 를 `protectedRecordID` 에 넣고 `finish` 에서 nil 로 돌린다.
  (`sync` 는 이미 앱 루트의 environmentObject 다.)
- [ ] **Step 4: 빌드.** `xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFit -destination "id=$IOS" build` → `BUILD SUCCEEDED`
- [ ] **Step 5: 커밋** — `✨ feat: 동기화 뒤와 iCloud 변경 때 겹친 기록을 정리한다`

### 작업 3: CloudKit 켜기

**Files:**
- Modify: `HaruchiFit.entitlements` (Xcode 가 고친다)
- Modify: `iOSApp/iOSApp.swift` — 컨테이너 선언 위 주석
- Modify: `CLAUDE.md`(HaruchiFit) — "데이터" 절에 iCloud 백업 · 중복 정리 한 줄
- Modify: `docs/plans/shared/2026/2026-10-19-release-checklist.md` — 결정 1 아래 "2026-11-18 이 플랜으로 켬" 한 줄

- [ ] **Step 1 (사용자):** Xcode › HaruchiFit 타깃 › Signing & Capabilities › `+ Capability` › iCloud › CloudKit 체크 › 컨테이너 `iCloud.com.yj.HaruchiFit` 추가.
  개발자 계정에 컨테이너를 등록하는 일이라 파일 수정만으로는 안 된다.
- [ ] **Step 2: 엔타이틀먼트 확인.** `HaruchiFit.entitlements` 가 골프(`GolfCounter.entitlements`)와 같은 두 키 — `com.apple.developer.icloud-container-identifiers` · `com.apple.developer.icloud-services`(CloudKit) — 를 갖고 HealthKit 키가 그대로인지 diff 로 본다.
  pbxproj 에 다른 변경이 섞이지 않았는지도 본다.
- [ ] **Step 3:** `iOSApp.swift` 의 "CloudKit 엔타이틀먼트가 아직 없다" 주석을 "CloudKit 미러링 — iCloud 를 끈 기기는 팩토리가 로컬로 폴백한다" 로 바꾼다. 문서 두 곳에 한 줄씩 더한다.
- [ ] **Step 4: 검증.** iOS 빌드 → `codesign -d --entitlements - <빌드된 HaruchiFit.app>` 에 두 iCloud 키가 보인다. `make lint` · `make format` · `HaruchiFitWatchTests` 전체 PASS.
- [ ] **Step 5: 커밋** — `🔧 chore: 하루치에 iCloud(CloudKit) 백업을 켠다`

### 작업 4: 스키마 배포와 TestFlight 확인

코드 변경 없음. 결과를 PR 본문 확인 목록에 적는다.

- [ ] **개발 스키마 만들기** — 시뮬레이터에 **테스트용 iCloud 계정**으로 로그인 → Debug 실행 → 수동 기록 하나 저장(구간 · 메모 · 부위 포함).
  CloudKit Console › `iCloud.com.yj.HaruchiFit` › Development 에 `CD_WorkoutRecord` · `CD_Segment` 레코드 타입이 생겼는지 본다
- [ ] **개발 환경에서 복원 · 중복 정리 리허설** — 같은 시뮬레이터(테스트 계정)에서 건강 앱 운동이 있는 상태로 기록을 쌓고 → 앱 삭제 → 다시 실행.
  구간 · 메모 · 부위가 돌아오고 같은 운동이 두 줄로 남지 않는지, **지우면 안 되는 기록이 지워지지 않는지** 여기서 먼저 본다.
  iCloud 동기화는 백업이 아니라 삭제도 전파되므로, 지우는 로직을 본인 아이폰(실서비스 데이터)에서 처음 돌리지 않는다
- [ ] **실서비스 배포** — Console › Deploy Schema Changes. 배포 뒤에는 필드를 지우거나 바꿀 수 없다
- [ ] **업데이트 경로** — 본인 아이폰: App Store 하루치 1.0.x 위에 TestFlight 빌드 설치 → 기존 기록 · 구간 · 메모가 그대로 보인다
- [ ] **재설치 경로** — 몇 분 뒤 앱 삭제 → TestFlight 로 다시 설치 → 온보딩 · 건강 권한 → 앱을 켠 채로 기다린다.
  구간(근력 · 유산소) · 부위 · 메모 · 수동 기록이 돌아오고, **같은 운동이 두 줄로 남지 않는다.** 잔디가 삭제 전과 같다.
  중복이 앱을 켠 채로 사라지면 원격 알림 경로가 돈 것이고, 백그라운드에 갔다 와야 사라지면 포그라운드 정리만 돈 것이다 — 어느 쪽인지 기록한다 (Review Focus 1)
- [ ] **iCloud 끔** — 설정 › iCloud › 하루치 끔 → 앱 실행 · 기록 저장이 지금처럼 된다
- [ ] **PR** — `feat/haruchi-icloud-backup` 브랜치, 본문에 `YJ-48`. 출시 노트(`APPSTORE.md`)는 출시 준비 커밋에서 "iCloud 백업" 을 적는다
