# YJKit

yj-apps 모노레포의 공용 iOS+watchOS 앱 인프라. 독립 라이브러리를 필요한 것만 골라 의존한다.
(Ralli 테니스 카운터에서 처음 추출했고, 이후 GolfCounter 등 다른 앱이 함께 쓴다.)

| Product | 역할 | 상태 |
|---|---|---|
| `WorkoutCore` | HealthKit 워크아웃 세션·칼로리·심박 측정 | ✅ |
| `WorkoutUI` | 폰·워치 공유 워크아웃 화면 (경과시간·kcal·BPM) | ✅ |
| `ConnectivityCore` | 폰↔워치 전송 (실시간/큐잉/컨텍스트) | ✅ |
| `PersistenceCore` | SwiftData + CloudKit 컨테이너/서비스 | ✅ |
| `WorkoutShareUI` | 워크아웃 결과 카드를 인스타그램 스토리로 공유 (iOS 전용) | ✅ |
| `MonitoringCore` | 크래시 리포팅 — `CrashReporting` 프로토콜 + Firebase Crashlytics 구현 | ✅ |

## WorkoutCore 사용법

```swift
import WorkoutCore

// 앱 루트에서 한 번 생성해 주입 (싱글톤 없음)
let workout = WorkoutSessionService(
    configuration: WorkoutConfiguration(activityType: .tennis)          // 테니스
    // .init(activityType: .golf)                                       // 골프
    // .init(activityType: .traditionalStrengthTraining, locationType: .indoor)  // 근력운동
)
```

- `startWorkout()/pauseWorkout()/resumeWorkout()/stopWorkout()`은 watchOS 전용.
- `stopWorkout()`은 `WorkoutResult`(시간·칼로리·평균심박·총칼로리) 반환.
- 라이브 데이터 (watchOS 전용):
  - `currentCalories` — 활동 에너지(activeEnergyBurned) 누적 kcal.
  - `currentBasalCalories` — 휴식 에너지(basalEnergyBurned) 누적 kcal. 총 칼로리는 `currentCalories + currentBasalCalories`.
    `HKLiveWorkoutDataSource`가 종목에 따라 basal을 자동 수집하며, 수집되지 않는 종목에서는 0으로 남는다.
- 테스트·프리뷰에서는 `#if DEBUG` 전용 `setLiveMetricsForTesting(heartRate:calories:basalCalories:elapsedSeconds:)`로 표시 값 주입.

## WorkoutUI 사용법

세 앱(테니스·골프·헬스)이 공유하는 워크아웃 화면. 표시 항목은 **경과시간·활동 kcal·총 kcal·BPM 4개 고정**이다.

```swift
import WorkoutUI

// Watch — 메트릭 탭
WorkoutMetricsView(metrics: viewModel.currentMetrics, isPaused: viewModel.isPaused)

// Watch — 컨트롤 탭
WorkoutControlsView(isPaused: viewModel.isPaused,
                    onPauseResume: { ... },
                    onEnd: { ... })

// iOS — 대시보드 (링 + 지표 3칸 + 컨트롤)
WorkoutDashboardView(metrics: viewModel.metrics,
                     isPaused: viewModel.isPaused,
                     isPauseAvailable: viewModel.watchConnected,
                     onPauseResume: { ... },
                     onEnd: { ... })
```

화면은 값과 콜백만 받는다 — 서비스나 ViewModel을 모른다. 라벨·색은 패키지가 소유하므로 앱이 문자열을 관리하지 않는다.

### 소비자 책임 (패키지가 대신 못 해주는 것)

- [ ] **칼로리는 워크아웃 누적값으로 넘긴다.** 경기/라운드 구간 값이 필요하면 저장 시점에 `종료값 - 시작값`으로 계산한다. 화면에 구간 델타를 넘기면 세 앱의 숫자 의미가 갈린다.
- [ ] **경과시간은 워치가 단일 소스.** 폰은 `WorkoutAnchor.interpolatedElapsed(anchorElapsed:isPaused:sentAt:now:)`로 매초 보간한다. 폰이 자체 타이머로 시간을 세면 pause 한 번에 두 기기가 어긋난다.
- [ ] **`WorkoutMetricsMessage`는 반드시 `.realtimeOnly`로 보낸다.** 앵커 보간은 `sentAt`이 "방금"이라는 전제 위에 있다 — `.reliable`(미도달 시 `transferUserInfo` 큐잉)이나 `.context`(콜드런치 시 재생)로 보내면 분·시간 단위로 묵은 앵커가 그대로 interpolation에 들어가 경과시간이 크게 틀어진다. 유실은 괜찮지만(다음 tick이 곧 온다) 지연은 안 된다.
- [ ] **pause는 폰→워치 명령이다.** 폰은 `WorkoutPauseMessage(sessionId:shouldPause:)`를 `.reliable`로 보내고, `isPaused`는 워치가 보낸 앵커로만 갱신한다 — **낙관적 토글 금지**. 명령을 모르는 구버전 워치에서 오동작 대신 무동작이 되도록 하는 장치다.
  `.reliable`은 미도달 시 큐잉되므로, 같은 세션 안에서 늦게 배달되면 `sessionId` 검사를 통과한 채 이미 재개된 워크아웃을 뒤늦게 일시정지시킬 수 있다. 수신 측은 방어적으로 `onReceive(WorkoutPauseMessage.self, maxAge: 30) { ... }`처럼 `maxAge`를 등록해 묵은 명령을 걸러내는 것을 권장한다 (ConnectivityCore 사용법 절 참고).
- [ ] **워치 미연결 시 `isPauseAvailable: false`.** 폰에는 HKWorkoutSession이 없어 누를 대상이 없다.
- [ ] `WorkoutMetricsMessage`의 `sentAt`은 `ConnectivityService`가 스탬프한다 — 발신 시 채우지 말 것.

### 와이어 포맷 (구버전 호환)

`WorkoutMetricsMessage`의 키는 `elapsed`/`calories`/`totalCalories`/`heartRate`/`isPaused`.
앞 넷은 초기 버전부터의 계약이라 이름을 바꾸지 않는다. 구버전이 `totalCalories`를 안 보내면
`calories`로, `isPaused`를 안 보내면 `false`로 폴백한다.

## WorkoutShareUI 사용법

워크아웃 결과 카드를 이미지로 만들어 iOS 공유 시트로 넘기는 버튼. 앱은 한 줄만 쓰면 된다.

```swift
import WorkoutShareUI

WorkoutShareButton(
    result: workoutResult,
    header: WorkoutShareHeader(title: String(localized: "share_title_tennis"),
                               startedAt: workoutStart, endedAt: workoutEnd),
    style: WorkoutShareStyle(badgeColor: .brand, logo: Image("AppLogo"))
)
```

카드는 **짙은 회색 카드 한 장**(1080×800px)이다. 스티커로 복사하면 둥근 모서리(바깥 투명), 공유 시트로
보내면 네모다. 피트니스 앱 운동 세부사항과
같은 구성이다.

- **머리줄** — 원형 로고(`badgeColor` 배경) · 제목 · "9월 9일 · 오후 7:27–오후 10:03"
- **2×2** — 운동 시간 · 활동 킬로칼로리 · 총 킬로칼로리 · 평균 심박수. 값 색은 시간 라임 ·
  칼로리 호박 · 심박 산호로 **패키지가 고정**한다. 앱 색은 원형 로고에만 쓰인다.

| 앱 | `badgeColor` | `logoColor` |
|---|---|---|
| Ralli | 라임 | 생략 → 검정 |
| GolfCounter | 짙은 초록 | 크림색 (`brandForeground`) |
| 하루치 핏 | 주황 | 생략 → 검정 |

`logoColor`를 생략하면 원 배경과 대비가 큰 쪽(검정/흰색)을 패키지가 고른다.

> 스토리 화면 크기(1080×1920)로 굽지 않는다. 그렇게 넘기면 인스타그램이 이미지를 배경으로 깔아
> 옮기거나 키울 수 없다.

버튼은 **공유 아이콘 하나**다 — 피트니스 앱 우상단 공유 버튼과 같은 모양. 배경은 두는 자리에 따라 다르다.

| `appearance` | 배경 | 쓰는 곳 |
|---|---|---|
| `.standalone` (기본) | 버튼이 직접 원을 그린다 (iOS 26 유리, 그 전은 짙은 회색) | 툴바가 아닌 자리 |
| `.toolbar` | **툴바가 그린다** | `ToolbarItem` 안 — 옆의 기본 버튼과 질감이 맞는다 |

누르면 메뉴가 뜬다.

- **공유…** — 카드 PNG 파일로 공유 시트를 띄운다. 공유 시트로 받은 사진에는 인스타가 배경을 붙이고
  **투명한 곳을 검정으로 채운다**. 그래서 이 경로만 모서리를 자르지 않은 **네모 카드**로 굽는다.
- **스티커로 복사** — 카드 PNG 를 클립보드에 넣는다. 인스타 스토리에서 자기 사진을 고른 뒤 화면을
  길게 눌러 붙여넣으면 **배경 없는 스티커**로 올라가 옮기고 키울 수 있다. Meta App ID 없이 스티커를
  만드는 경로다.

둘 다 PNG 로 넘긴다 — `UIImage` 를 그대로 넘기면 받는 쪽이 JPEG 로 바꿔 모서리 투명이 사라진다.

> 인스타그램 스토리 딥링크(`instagram-stories://`)로 스티커를 넘기던 경로는 2026-09-13 에 걷어냈다.
> Facebook App ID 가 필수인데 발급을 받지 못했다. 되살릴 때는
> [제거 플랜](docs/plans/ios/2026/2026-09-13-share-sheet-only.md)과 그 이전 커밋을 본다.

칸은 **항상 네 개**다. 값이 없는 지표(`averageHeartRate`가 nil, 칼로리가 0)는 칸을 빼지 않고
**`–`** 로 표시한다 — 기록마다 카드 크기와 배치가 달라지지 않게.

버튼 라벨·지표 라벨·레이아웃·카드 색은 패키지가 소유한다. 앱은 제목 문자열만 현지화해서 넘긴다.

### 소비자 책임 (패키지가 대신 못 해주는 것)

- [ ] **`WorkoutResult`는 워크아웃 누적값으로 넘긴다.** 구간 델타를 넘기면 두 앱의 숫자 의미가 갈린다 — `WorkoutUI`와 같은 규칙이다.
- [ ] **`WorkoutShareHeader`의 시각은 카드 숫자와 같은 구간이어야 한다.** 누적값을 넘겼으면 워크아웃 시작 ~ 그 누적값을 잰 시점이다.
- [ ] **제목은 앱이 현지화한다.** 패키지는 종목을 모른다.
- [ ] **iOS 전용이다.** 워치 타깃에서 임포트해도 심볼이 없다.

## MonitoringCore 사용법

크래시는 SDK 가 알아서 잡는다. 이 프로덕트는 **non-fatal 과 브레드크럼** 을 앱이 프로토콜로 보내게 한다.

```swift
import MonitoringCore

// 앱 진입점 — 초기화 시점은 앱이 정한다. 앱은 FirebaseCore 를 직접 링크하지 않는다.
// 번들에 GoogleService-Info.plist 가 있으면 Firebase 를 켜고 Crashlytics 리포터를,
// 없으면(CI·새 체크아웃) 아무것도 안 건드리고 NoopCrashReporter 를 돌려준다
let reporter: CrashReporting = CrashlyticsReporter.start()

// 주입. 코어는 싱글톤을 두지 않는다 — 앱이 어디에 들고 있을지 정한다
let vm = SomeViewModel(crashReporter: reporter)

// non-fatal — 같은 종류는 같은 domain+code 로. 메시지는 자유
reporter.record(
    MonitoringError(domain: "Ralli.Save", code: 1, message: "ack timeout"),
    context: ["sessionId": id.uuidString]
)

// 브레드크럼 — 크래시 직전 맥락. 자주 부르지 않는다
reporter.log("match started")
```

`CrashlyticsReporter` 는 `start()` 로만 얻는다. 초기화 없이 만들어지면 첫 호출에서 죽기 때문이다.
테스트·프리뷰는 `NoopCrashReporter()`. 호출을 검사하는 스파이의 형태는
`Tests/MonitoringCoreTests/CrashReportingSpy.swift` 에 있다 — 테스트 타깃은 export 되지 않으니 복사해 쓴다.

### 소비자 책임 (패키지가 대신 못 해주는 것)

- [ ] Firebase 콘솔에서 프로젝트를 만들고 **앱(번들 ID)마다** `GoogleService-Info.plist` 를 받아 타깃 폴더에 넣는다. iOS·워치는 별개 앱이다.
- [ ] **plist 는 git 에 넣지 않는다** (저장소가 공개 — 루트 `.gitignore` 가 막는다). 새 체크아웃·워크트리에는 콘솔에서 다시 받아 넣는다. 없으면 Noop 으로 돌 뿐 빌드·테스트는 깨지지 않는다.
- [ ] 각 앱 진입점 `init` 에서 `CrashlyticsReporter.start()`. 익스텐션에서는 부르지 않는다.
- [ ] 타깃마다 dSYM 업로드 Build Phase (`upload-symbols`). `ENABLE_USER_SCRIPT_SANDBOXING = YES` 면 **조용히 실패**한다.
- [ ] **그 스크립트가 Release 에서 plist 존재를 검사해 없으면 아카이브를 실패시킨다.** plist 없이 출시하면 수집이 조용히 꺼진다 — Noop 폴백의 대가다.
- [ ] App Privacy 라벨에 Crash Data · Other Diagnostic Data.
- [ ] 수집 끄기 UI 를 둔다면 `Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)`.

## ConnectivityCore 사용법

```swift
import ConnectivityCore

// 메시지 정의는 앱 몫 — 프로토콜만 채택하면 된다
struct RoundRecordMessage: ConnectivityMessage {
    static let messageType = "roundRecord"
    let holeScores: [Int]
    init?(from dictionary: [String: Any]) { ... }
    func toDictionary() -> [String: Any] { ... }
}

let connectivity = ConnectivityService()
// ⚠️ 서비스는 프로세스당 정확히 하나만 생성할 것 — 두 번째 인스턴스가 WCSession delegate를 빼앗아 첫 인스턴스의 수신이 조용히 죽는다.
// ⚠️ onReceive 등록은 서비스를 생성한 그 main-queue turn 안에서 마칠 것 —
//    콜드런치 applicationContext 배달이 등록 전에 도착하면 유실된다.
connectivity.onReceive(RoundRecordMessage.self, maxAge: 60) { record in ... }

// 전송: .realtimeOnly(미도달 드롭) / .reliable(transferUserInfo 큐잉) / .context(마지막 상태 보존)
connectivity.send(RoundRecordMessage(...), via: .reliable)
```

- 코어가 모든 발신에 `type`·`sentAt`을 스탬프한다. `maxAge`는 sentAt 기준이며, sentAt 없는 수신(구버전)은 stale로 보지 않는다.
- sticky 값이 필요하면(SwiftUI `@Published` 구독) 앱 레이어에서 얇은 래퍼로 복원할 것 — 테니스 앱의 `MatchConnectivity` 참조.

## PersistenceCore

SwiftData + CloudKit 컨테이너 팩토리와 제너릭 CRUD 서비스. `@Model` 클래스는 앱 몫.

### 사용법

```swift
// 앱 루트: CloudKit 시도 → 미로그인/시뮬레이터는 로컬 폴백
let container = PersistenceContainerFactory.make(for: [MyRecord.self])

// CRUD: predicate·정렬은 호출부가 주입
let store = PersistenceService<MyRecord>(context: ModelContext(container))
try store.upsert(record, replacing: #Predicate { $0.sessionId == sid })
let history = try store.fetchAll(sortBy: [SortDescriptor(\.endedAt, order: .reverse)])
```

### CloudKit 체크리스트 (소비자 앱 책임)

- 엔타이틀먼트: iCloud → CloudKit + 컨테이너 ID, Background Modes → Remote notifications
- `@Model` CloudKit 규칙: 모든 속성 optional 또는 기본값, `@Relationship`은 optional + `inverse` 명시, `.unique` 제약 금지
- 시뮬레이터/미로그인 환경은 자동으로 로컬 폴백된다 (동기화 없음)

### 주의

- `PersistenceService`는 `@MainActor` — 백그라운드 컨텍스트 미지원 (필요해지면 그때 확장)
- 단일 ModelContext 전제: 같은 컨텍스트를 공유하는 다른 쓰기 경로와 rollback이 간섭할 수 있다

## 소비자 앱 체크리스트 (패키지가 대신 못 해주는 것)

- [ ] 타겟 Capability에 **HealthKit** 추가 (엔타이틀먼트)
- [ ] Info.plist에 `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription` 문구
- [ ] watchOS 타겟 최소 버전 10.0, iOS 17.0

## 개발 워크플로

- 이 모노레포의 앱은 `../../Packages/YJKit` 로컬 SPM 패키지를 직접 참조한다.
- 패키지 소스를 수정하면 앱 재빌드 시 즉시 반영된다. 원격 태그, 별도 체크아웃, local override 설정은 필요하지 않다.
- 패키지 단독 검증은 저장소 루트에서 아래처럼 공용 스크립트가 선택한 iOS 시뮬레이터 UDID를 사용한다.

  ```bash
  make kit-test KIT_DESTINATION="id=$(.github/scripts/pick-simulator.sh iOS '^iPhone')"
  ```
