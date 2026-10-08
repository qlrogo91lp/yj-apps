# 08 수동 기록 추가 구현 계획

상태: 사용자 승인 (2026-10-08). 구현은 `feat/haruchi-manual-record` 워크트리에서 진행한다.

## 목표와 결정

- 워치·HealthKit 없이 시작 시각과 운동 시간만으로 기록을 만들 수 있다. 근력·유산소는 한 유형만 고른다.
- 생성·편집에 같은 폼을 쓴다. 부위 6개와 메모는 선택 입력이다.
- 상세 `편집`은 수동 기록에만 보인다. 워치·import 기록은 HealthKit이 운동 수치의 원본이므로 기존 부위·메모 즉시 편집만 제공한다.
- 수동 기록은 `source = .manual`, `healthKitUUID = nil`, 단일 `Segment`이며 칼로리·심박은 없다. HealthKit 호출 없이 SwiftData에 저장한다.
- 날짜·시간·유형 수정은 기존 모델을 제자리 갱신한다. 저장 실패는 롤백하고 폼 초안을 유지한다.
- 잔디는 입력 시간을 시간 기준 농도에 사용한다. 칼로리 기준을 나중에 선택하면 값이 없어 최소 농도다.
- 기능 코드를 먼저 끝내고 실기기 통합 검증은 마지막에 묶는다.

## Task 1 — 모델 규칙과 테스트

**Files:**
- Create: `Shared/Models/ManualRecordDraft.swift` — 시작 시각·운동 시간·단일 유형·부위·메모 입력과 검증.
- Create: `Shared/Persistence/WorkoutRecord+Manual.swift` — 생성과 기존 수동 기록 제자리 갱신. 종료 시각과 단일 세그먼트 동기화.
- Create: `watchosTests/Models/ManualRecordTests.swift` — 필수 입력, 범위, 생성, 편집, 기존 기록 보호, 집계 영향.

**순서:** 테스트를 먼저 작성해 실패를 확인한 뒤 최소 구현, 워치 테스트 재실행. 시작 시각은 종료된 운동을 가리키며, 기본값은 현재보다 60분 전·60분 운동이다. 1분 미만·미래에 끝나는 입력은 거부한다. 날짜 경계는 `startedAt` 기준이다.

## Task 2 — 저장과 폼

**Files:**
- Create: `iOSApp/Services/ManualRecordStore.swift` — `ModelContext` 삽입·기존 모델 갱신·save/rollback. HealthKit 의존 없음.
- Create: `iOSApp/Features/Records/Manual/ManualRecordViewModel.swift` — 공용 폼 상태·검증·저장 결과.
- Create: `iOSApp/Features/Records/Manual/ManualRecordView.swift` — 날짜·시각, 운동 시간, 근력/유산소, 부위 6개, 메모, 취소·저장.
- Modify: `iOSApp/AppAlert.swift` — 수동 저장 실패 안내.

**검증:** 모델 규칙은 Task 1 테스트로, iOS 배선은 워크스페이스 빌드로 확인한다. 취소 시 영속 데이터가 바뀌지 않고, 오류 시 입력 초안이 남는지 UI 확인 목록에 넣는다.

## Task 3 — 홈·상세·목록 연결

**Files:**
- Modify: `iOSApp/Features/Home/HomeView.swift` — 상단 `+`, 생성 후 홈·잔디 갱신.
- Modify: `iOSApp/Features/Records/Detail/RecordDetailView.swift` — 수동 기록에만 `편집` 표시.
- Modify: `iOSApp/Features/Records/Detail/RecordDetailSheet.swift` — 상세 종료 후 동일 폼 열기, 편집 저장 후 호출 화면 갱신.
- Move: `iOSApp/Features/Records/Detail/Components/BodyPartChips.swift` → `iOSApp/Features/Records/Components/BodyPartChips.swift` — 상세와 수동 폼이 쓰는 기록 Feature 공용 칩.
- Modify: `iOSApp/Features/Records/RecordsView.swift` — 수정·생성에 따른 주 섹션 갱신, 빈 상태의 수동 진입 안내.
- Modify: `iOSApp/Features/Statistics/StatisticsView.swift` — 속성만 바뀐 기록도 재집계하는 기존 값 스냅샷 경로 확인·보강.

**검증:** 새 기록이 홈·기록·통계에 나타나고, 날짜·시간·유형 편집 후 기존 잔디 칸과 새 칸, 주 섹션, 연도별 집계가 맞는지 확인한다. 상세 시트와 폼 전환 시 삭제된 모델을 읽지 않도록 한다.

## Task 4 — 전체 검증과 문서

**Files:**
- Modify: `Shared/Models/GrassIntensity.swift`, `iOSApp/Features/Home/GrassViewModel.swift`, `Shared/Persistence/WorkoutRecord.swift` — 수동 기록 이전의 낡은 설명만 현재 규칙에 맞게 수정.
- Modify: `docs/specs/shared/2026/2026-09-02-haruchi-fit-product-spec.md` — D4의 최소 농도 문장을 확정된 잔디 상세 스펙과 일치시킴.
- Modify: `docs/specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md`, 루트 `TODO.md` — 구현·로컬 검증 결과와 실기기 대기 상태를 기록. 루트의 기존 미커밋 변경은 건드리지 않는다.

**명령:** 워치 테스트 스킴 전체, iOS 앱 빌드, `swiftlint`, `swiftformat --lint .`를 워크스페이스·앱 규약대로 실행한다. 시뮬레이터는 이름 대신 UDID를 쓴다.

**마지막 실기기 통합 확인:** HealthKit 거부·워치 없음에서 생성, 1분 미만·미래 종료 거부, 근력/유산소 한 구간, 부위·메모 유지, 날짜를 넘기는 편집, 홈 잔디·목록·통계 동시 반영, 앱 재실행 후 유지, 삭제, 워치/import 기록에 편집 버튼이 없는지 확인한다. 이 항목은 다른 기능의 실기기 검증과 묶어 진행한다.

커밋·PR은 구현과 로컬 검증 결과를 사용자에게 검토받은 뒤 진행한다.

## 구현 중 판단과 확인 상태

- 폼 오류는 해당 시트 안에서 초안을 유지한 채 보여 준다. 따라서 `AppAlert.swift` 수정은 필요하지 않았다.
- 통계 탭은 이미 `StatisticsRecordInput` 값 스냅샷과 화면 재진입 시 재집계 경로를 갖고 있어 `StatisticsView.swift` 수정 없이 수동 기록이 반영된다. 날짜·유형 변경을 목록·잔디·통계에 함께 반영하는 테스트를 추가했다.
- 상세에서 메모 저장에 실패한 상태로 `편집`을 누르면 보관된 초안을 폼에 넘긴다. 폼 저장이 성공한 뒤에만 초안을 지워, 오래된 초안이 새 메모를 덮지 않게 한다.
- 루트 `TODO.md`는 main 워크트리의 다른 세션 미커밋 변경을 보호하기 위해 이번 브랜치에서 수정하지 않았다.
- 워치 전체 테스트·iOS 앱 빌드·lint·format은 통과했다. 이 환경에는 Simulator GUI 앱이 없어 시트 전환·폼 조작의 화면 확인은 실기기 통합 검증으로 남긴다.
