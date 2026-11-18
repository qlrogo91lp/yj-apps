# 하루치·Ralli 마지막 운동 스티커 복사 단축어 구현 플랜

> 구현은 이 플랜의 사용자 승인 후 시작한다. 이 세션에서 순서대로 구현한다면 `superpowers:executing-plans`를 사용한다.

**목표** — iOS 단축어 앱에 두 앱의 **마지막 운동 스티커 복사**를 기본 제공한다. 실행하면 앱 상세 화면을 열지 않고 투명 PNG를 복사하고, 어느 운동을 복사했는지 종료 날짜와 시각을 실행 결과에 표시한다.

**설계** — 각 iOS 앱의 `AppIntent`가 자기 저장소에서 종료 시각이 가장 늦은 운동을 찾는다. 상세 화면과 단축어는 각 앱의 카드 입력과 `WorkoutShareUI`의 렌더링·클립보드 쓰기를 공유한다.

**기술** — App Intents · SwiftData · SwiftUI `ImageRenderer` · UIKit `UIPasteboard` · Swift Testing

**요구사항** — [YJ-48](https://linear.app/yj-workpace/issue/YJ-48/하루치ralli에-마지막-운동-스티커-복사-단축어-추가)과 대화에서 확정한 동작을 반영했다.

## 동작과 범위

- 두 앱 모두 iOS 17부터 지원한다. iOS 앱 타깃마다 `AppShortcutsProvider` 하나에 파라미터 없는 단축어 하나를 등록한다. 한국어 이름은 `마지막 운동 스티커 복사`, 영어는 `Copy Last Workout Sticker`다.
- 기기에 저장된 각 앱의 운동을 대상으로 하고 날짜 제한을 두지 않는다. 두 운동의 종료 시각이 같으면 시작 시각이 늦은 쪽을 고른다. 하루치는 상세에 쓰는 `effectiveEndedAt`을 기준으로 한다. Ralli는 종료 시각이 있는 `WorkoutSessionRecord`가 기준이며 경기를 저장하지 않은 세션도 포함한다.
- Ralli에서 최종 운동 레코드 없이 경기만 있는 데이터에는 진행 중인 운동의 경기와 이전 버전의 경기 기록이 모두 들어갈 수 있다. 단축어는 확정된 운동 종료 기록을 대상으로 한다. 이전 버전 경기 카드 공유는 기존 상세 화면의 경로를 이용한다.
- 정상 결과는 `2026년 11월 17일 오후 7:42에 끝난 운동을 스티커로 복사했어요.`처럼 표시한다. 날짜와 시간은 `Date.FormatStyle(date: .long, time: .shortened)`로 기기의 지역·시간대 설정을 따른다. 단축어 결과 메시지(`IntentDialog`)만 사용한다.
- 기록이 없으면 `저장된 운동 기록이 없어요.`를 표시한다. 마지막 운동의 지표가 부족하거나 읽기·렌더링·PNG 변환에 실패하면 `마지막 운동 스티커를 복사하지 못했어요.`를 표시하고 현재 클립보드 내용을 보존한다. 복사 가능한 이전 운동을 대신 고르지 않는다.
- 읽는 시점은 단축어를 실행했을 때다. 워치에서 가장 최근에 저장한 운동의 동기화가 늦으면 아이폰에 있는 기록을 기준으로 하고, 그 기록의 실제 날짜를 결과에 표시한다.

## 작업 1 — YJKit에서 스티커 복사 경로 공유

| 변경 파일 | 작업 |
| --- | --- |
| `Packages/YJKit/Sources/WorkoutShareUI/Share/WorkoutShareExport.swift` | `WorkoutShareExport`를 공개하고 `@MainActor public static func copySticker<Accessory: View>(result: WorkoutResult, header: WorkoutShareHeader, style: WorkoutShareStyle, accessory: Accessory?, to pasteboard: UIPasteboard = .general) -> Bool`을 추가한다. 기존 `.rounded` 렌더와 이미지용 `copySticker`에 위임한다. |
| `Packages/YJKit/Sources/WorkoutShareUI/WorkoutShareButton.swift` | 메뉴의 스티커 복사를 공개 API로 연결한다. 기존 복사 완료 UI와 공유 시트용 `.square` 렌더를 사용한다. |
| `Packages/YJKit/Sources/WorkoutShareUI/Render/WorkoutShareRenderer.swift` | 이미지 생성 실패를 로그와 `nil`로 전달해 호출부가 실패를 처리할 수 있게 한다. |
| `Packages/YJKit/Tests/WorkoutShareUITests/WorkoutShareExportTests.swift` | 이름 있는 테스트 클립보드에 새 API로 복사하고 `UTType.png`와 모서리의 알파 값 `0`을 검증한다. |

- [ ] `copyStickerFromCardPutsTransparentPNGOnPasteboard`를 추가하고 공개 카드 API가 생기기 전에는 테스트가 컴파일에 실패하는지 확인한다.
- [ ] 렌더·복사를 연결하고 `make kit-test KIT_DESTINATION="id=$IOS"`를 실행한다. 기존 공유 시트와 PNG 테스트도 모두 통과해야 한다.

## 작업 2 — 하루치에 단축어 추가

| 변경 파일 | 작업 |
| --- | --- |
| `Apps/HaruchiFit/iOSApp/iOSApp.swift` | 기존 설정으로 앱 프로세스에서 `HaruchiFitApp.modelContainer` 하나를 만들고, 앱 초기화와 단축어가 같은 저장소를 쓴다. 단축어 실행에서는 이 컨테이너로 읽기용 `ModelContext`를 만든다. |
| `Apps/HaruchiFit/Shared/Models/RecordShareBuilder.swift` | `static func latestRecord(in records: [WorkoutRecord]) -> WorkoutRecord?`를 추가해 `effectiveEndedAt`, `startedAt` 순으로 가장 늦은 운동을 선택한다. 기존 `content(for:)`를 그대로 사용한다. |
| `Apps/HaruchiFit/iOSApp/Features/Records/Detail/Components/RecordShareButton.swift` → `Apps/HaruchiFit/iOSApp/Components/RecordShareButton.swift` | 상세 버튼과 `@MainActor static func copySticker(content: RecordShareContent) -> Bool`에서 같은 헤더, 로고, 색상, 운동 구성 뷰를 사용한다. |
| `Apps/HaruchiFit/iOSApp/Features/Records/Detail/Components/{ShareComposition,CompositionCaption,SegmentTimelineBar}.swift` → `Apps/HaruchiFit/iOSApp/Components/` | 공유 카드와 기록 상세가 쓰는 구성 뷰를 앱 컴포넌트로 옮긴다. |
| `Apps/HaruchiFit/iOSApp/AppIntents/CopyLastWorkoutStickerIntent.swift` | `@MainActor perform() async throws -> some IntentResult & ProvidesDialog`로 저장된 `WorkoutRecord` 조회, 선택, 기존 카드 복사, 결과 처리를 잇는다. |
| `Apps/HaruchiFit/iOSApp/AppIntents/HaruchiAppShortcuts.swift` | `AppShortcutsProvider`에 단축어 하나를 등록한다. Siri 실행 문구에는 `\(.applicationName)`을 포함한다. |
| `Apps/HaruchiFit/iOSApp/Localizable.xcstrings`, `Apps/HaruchiFit/iOSApp/AppShortcuts.xcstrings` | 전자는 고칠 파일로 제목·설명·결과를 추가한다. 후자는 새로 만들어 한국어·영어 Siri 문구를 등록한다. |
| `Apps/HaruchiFit/watchosTests/Models/RecordShareBuilderTests.swift` | 기존 Swift Testing 타깃에서 공유 선택 함수를 검증한다. |

- [ ] `latestRecordSelectsByEndDateAcrossDays`, `latestRecordDerivesMissingEndDate`, `latestRecordUsesStartDateForEqualEndDates`, `latestRecordReturnsNilForEmptyHistory`를 작성한다. 시작이 더 늦은 다른 운동이 있어도 종료가 늦은 쪽을 고르는 과거 날짜 사례를 포함한다.
- [ ] 기존 타깃에서 실패를 확인한 후 선택·복사·단축어 등록을 구현한다. `HaruchiFitWatchTests`와 `HaruchiFit` 빌드가 통과해야 한다.

## 작업 3 — Ralli에 단축어 추가

| 변경 파일 | 작업 |
| --- | --- |
| `Apps/TennisCounter/iOSApp/iOSApp.swift` | 기존 설정으로 `TennisCounterApp.modelContainer`를 만들고 앱·단축어에서 공유한다. 앱 초기화에서 기존 경기·세션 저장 서비스를 같은 방식으로 구성한다. |
| `Apps/TennisCounter/iOSApp/Services/SessionPersistenceService.swift` | `func fetchLatestEnded() throws -> WorkoutSessionRecord?`를 추가한다. `endedAt != nil`인 세션을 `endedAt`, `startedAt` 내림차순으로 정렬하고 `fetchLimit = 1`로 읽는다. 미구성 상태는 `PersistenceError.notConfigured`로 전달한다. |
| `Apps/TennisCounter/Shared/Models/SessionShareData.swift` | `init?(record: WorkoutSessionRecord)`에서 최종 운동 레코드의 시간·칼로리·심박을 카드 데이터로 변환한다. `init?(session:)`은 레코드가 있으면 새 초기화에 위임하고, 경기만 있는 기존 상세 카드의 변환은 유지한다. |
| `Apps/TennisCounter/iOSApp/Features/History/Components/SessionShareButton.swift` → `Apps/TennisCounter/iOSApp/Components/SessionShareButton.swift` | 상세 버튼과 `@MainActor static func copySticker(_ share: SessionShareData) -> Bool`이 같은 헤더·브랜드 스타일을 사용하도록 한다. |
| `Apps/TennisCounter/iOSApp/AppIntents/CopyLastWorkoutStickerIntent.swift` | 하루치와 같은 실행 인터페이스를 사용한다. 공유 컨테이너의 새 `ModelContext`로 세션 저장소를 구성하고, 조회한 단일 레코드로 복사를 시도한다. |
| `Apps/TennisCounter/iOSApp/AppIntents/RalliAppShortcuts.swift` | Ralli의 앱 단축어 하나를 등록한다. Siri 실행 문구에 `\(.applicationName)`을 포함한다. |
| `Apps/TennisCounter/iOSApp/Localizable.xcstrings`, `Apps/TennisCounter/iOSApp/AppShortcuts.xcstrings` | 전자는 고칠 파일로 제목·설명·결과를 추가한다. 후자는 새로 만들어 한국어·영어 Siri 문구를 등록한다. |
| `Apps/TennisCounter/iosTests/Services/SessionPersistenceServiceTests.swift`, `Apps/TennisCounter/iosTests/Shared/SessionShareDataTests.swift` | 종료 시각 우선 선택과 경기 없는 레코드의 카드 입력을 검증한다. |

- [ ] `fetchLatestEndedOrdersByEndDateThenStartDate`, `fetchLatestEndedIgnoresMissingEndDate`, `fetchLatestEndedReturnsNilForEmptyStore`, `shareDataUsesFinalRecordWithoutMatches`, `shareDataRequiresTimeAndActiveCalories`를 작성한다. 종료가 가장 늦은 세션에 지표가 없어도 저장소가 그 세션을 반환하는지 함께 확인한다.
- [ ] 테스트 실패를 확인한 후 선택·복사·단축어 등록을 구현한다. `TennisCounter` 스킴의 iOS 테스트가 통과해야 한다.

## 작업 4 — 빌드와 실기기 검증

- [ ] 아래 명령을 실행한다. 빌드·테스트가 모두 통과하고, 양쪽 iOS 빌드에서 App Intents 메타데이터 추출 또는 앱 이름 문구에 관한 오류가 없어야 한다. App Shortcuts 문구는 앱 이름 자리표시자가 필요하다. [Apple App Shortcuts 안내](https://developer.apple.com/videos/play/wwdc2025/244/) · [Apple 단축어 현지화 안내](https://developer.apple.com/videos/play/wwdc2023/10102/)

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
make kit-test KIT_DESTINATION="id=$IOS"
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFit -destination "id=$IOS" build
xcodebuild -workspace YJApps.xcworkspace -scheme HaruchiFitWatchTests -destination "id=$WATCH" test
xcodebuild -workspace YJApps.xcworkspace -scheme TennisCounter -destination "id=$IOS" -only-testing:RalliTests test
(cd Apps/HaruchiFit && swiftlint && swiftformat --lint .)
(cd Apps/TennisCounter && swiftlint && swiftformat --lint .)
```

- [ ] 아이폰에 두 앱의 새 빌드를 설치하고 단축어 앱의 각 앱 항목에 자동 등록되는지 확인한다. 설치와 기존 버전에서 업데이트하는 경우를 모두 확인한다.
- [ ] 앱을 화면에 띄우지 않은 상태에서 단축어 앱과 동작 버튼으로 실행한다. 앱 화면을 열지 않고 복사되는지, 시스템이 종료 날짜·시간을 어떻게 보여주는지 확인한다. Siri 한국어·영어 실행 문구도 확인한다.
- [ ] 이전 날짜 운동도 복사되는지, 같은 날 두 운동 중 종료가 늦은 쪽을 복사하는지 확인한다. Ralli에서는 경기가 없는 종료 운동을 포함하고, 진행 중에 경기만 저장했을 때 직전에 종료한 운동을 가져오는지 확인한다.
- [ ] 다른 텍스트를 복사해 둔 상태에서 기록 없음과 카드에 필수 지표가 없는 경우를 실행해 결과 문구와 클립보드 보존을 확인한다. 복사에 성공한 카드의 투명 모서리와 앱별 외형은 인스타 스토리에 붙여넣어 상세 화면 공유 결과와 비교한다.
- [ ] Git 작업을 함께 승인받으면 `feat/last-workout-sticker-shortcut` 브랜치에서 검증한 변경을 커밋하고 한 PR로 제출한다. PR 본문에는 `YJ-48`을 적는다. 두 앱의 App Store 배포는 각각의 다음 버전 심사에 포함한다.
