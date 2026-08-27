# RalliKit SPM 추출 타당성 검토

- 작성일: 2026-06-29 / **갱신: 2026-07-13** (소비자 앱 2개 확정, 패키지·레포 전략 및 API 설계 구체화)
- 상태: **설계 확정 (구현 착수 전)** — 미커밋
- 동기: `Shared/Services/`의 HealthKit·WatchConnectivity·SwiftData(+CloudKit) 인프라를 SPM 패키지로 분리해 세 앱에서 재사용.

## 결론

**별도 GitHub 레포 1개에 멀티 product SPM 패키지를 만들고, 세 코어를 전부 추출한다.**

6월 검토에서는 "Persistence는 초기 스킵"을 권장했으나, 소비자 앱이 확정되면서 뒤집혔다 — 세 코어 모두 소비자가 3개다.

### 소비자 매트릭스 (2026-07-13 확정)

| 재사용 대상 | 테니스 (Ralli) | 헬스 기록 (신규) | 골프 카운터 (업데이트) |
|---|---|---|---|
| HealthKit 워크아웃 측정 | ✅ `.tennis` | ✅ `.traditionalStrengthTraining` (근력운동) | ✅ `.golf` |
| WC 전송 코어 | ✅ 실시간 + 큐잉 | ✅ 큐잉 위주 | ✅ 큐잉 위주 (실시간 불필요) |
| SwiftData + CloudKit 컨테이너/서비스 | ✅ | ✅ | ✅ |

- **헬스 기록 앱 (신규)**: Watch에서 측정 + 폰에서 기록 확인. Ralli와 같은 구조.
- **골프 카운터 (업데이트)**: 기존 [golf_counter](https://github.com/qlrogo91lp/golf_counter)는 2023년 초기 버전 (iOS+Watch 타겟, Model/View 타겟별 중복, 인프라 없음). 업데이트에서 HealthKit 측정 + 라운드 기록 저장·히스토리 추가. 워치→폰 전송은 필요하되 실시간 동기화는 불필요 — 이게 정확히 현재 `sendReliably`(reachable이면 즉시, 아니면 `transferUserInfo` 큐잉)의 동작이다.
- CloudKit은 별도 API가 아니라 **SwiftData의 CloudKit 동기화 옵션** (`iOSApp.swift`의 `ModelConfiguration(cloudKitDatabase: .automatic)` + 미로그인 시 로컬 폴백). PersistenceCore에 컨테이너 팩토리로 포함한다. Core Data 직접 사용은 없음.

## 레포 전략

**접근 A (채택): 별도 레포 1개 + 멀티 product 패키지**

- 레포는 패키지당 하나가 아니라 **하나만**. 그 안에 독립 라이브러리 3개 (서로 의존 없음). 앱은 필요한 product만 골라 의존.
- 개발 중: 로컬 체크아웃을 Xcode 프로젝트에 드래그하면 원격 참조를 오버라이드 → 수정 즉시 반영.
- 배포: git tag(semver) + `.upToNextMajor`. 태깅이 번거로운 초반에는 `branch: "main"` 참조로 가고 앱 스토어 릴리즈 시점에만 태그를 찍는 절충이 현실적.

기각한 대안:
- **B. 테니스 레포 루트에 Package.swift**: SPM 원격 참조는 레포 루트에 Package.swift가 필요 → 테니스 레포가 곧 패키지 레포가 되어, 골프·헬스가 테니스 앱 소스 전체를 의존성으로 끌어오고 앱 릴리즈 태그와 패키지 버전 태그가 섞임.
- **C. 파일 복사**: 공수 최소(반나절)지만 콜드런치/staleness 버그 픽스가 복사본 3개로 갈라짐. 새 앱에서 같은 버그가 또 터진다.

### 네이밍 (2026-07-13 확정)

**패키지명: `RalliKit`** — 이 인프라가 Ralli(테니스 앱)에서 파생됐음을 이름에 남긴다. 개인 사용 전제라 타 앱(골프·헬스)에서 `import` 시의 브랜드 어색함은 감수. 레포명은 `ralli-kit`.

- ⚠️ 가칭이던 "WorkoutKit"은 **Apple 공식 프레임워크(iOS 17 WorkoutKit)와 모듈명이 충돌**해서 기각. `RalliKit`은 충돌 없음.
- product/모듈명(`WorkoutCore`·`ConnectivityCore`·`PersistenceCore`)은 그대로 유지 — Apple 프레임워크와 겹치지 않는다.

## 패키지 구조

```
ralli-kit/                        # 새 GitHub 레포 (1개)
├── Package.swift
├── Sources/
│   ├── WorkoutCore/              # HealthKit 워크아웃 측정
│   ├── ConnectivityCore/         # WC 전송 코어
│   └── PersistenceCore/          # SwiftData + CloudKit 컨테이너/서비스
├── Tests/
│   ├── WorkoutCoreTests/
│   ├── ConnectivityCoreTests/    # staleness·라우팅 등 순수 로직 테스트가 앱에서 이동
│   └── PersistenceCoreTests/
└── README.md                     # 소비자 가이드: @Model CloudKit 규칙, 엔타이틀먼트 체크리스트
```

```swift
// Package.swift
let package = Package(
    name: "RalliKit",
    platforms: [.iOS(.v17), .watchOS(.v10)],
    products: [
        .library(name: "WorkoutCore", targets: ["WorkoutCore"]),
        .library(name: "ConnectivityCore", targets: ["ConnectivityCore"]),
        .library(name: "PersistenceCore", targets: ["PersistenceCore"]),
    ],
    targets: [
        .target(name: "WorkoutCore"),
        .target(name: "ConnectivityCore"),
        .target(name: "PersistenceCore"),
        .testTarget(name: "WorkoutCoreTests", dependencies: ["WorkoutCore"]),
        .testTarget(name: "ConnectivityCoreTests", dependencies: ["ConnectivityCore"]),
        .testTarget(name: "PersistenceCoreTests", dependencies: ["PersistenceCore"]),
    ]
)
```

- 엔타이틀먼트·Info.plist(HealthKit 권한 문구, iCloud 컨테이너 ID, WC capability)는 **각 앱 타겟에 잔류**. SPM 구조적 제약 — README 체크리스트로 명시.
- 현재의 `#if os(watchOS)` 분기 그대로 동작.
- 공통 원칙: 싱글톤(`static let shared`) → `public init` DI 전환. 앱 루트에서 한 번 생성해 주입.

## 코어별 설계

### 1. WorkoutCore (HealthKit) — 가장 깔끔, 1순위

바꿀 것 세 가지뿐: ① `.tennis` 하드코딩 → 설정 주입, ② 싱글톤 → DI, ③ `public` 접근제어.

```swift
public struct WorkoutConfiguration {
    public let activityType: HKWorkoutActivityType
    public let locationType: HKWorkoutSessionLocationType
    public init(activityType: HKWorkoutActivityType,
                locationType: HKWorkoutSessionLocationType = .outdoor)
}

public final class WorkoutSessionService: NSObject, ObservableObject {
    @Published public private(set) var isWorkoutActive, isPaused: Bool
    @Published public private(set) var currentHeartRate, currentCalories: Double
    @Published public private(set) var elapsedSeconds: Int

    public init(configuration: WorkoutConfiguration)
    public func requestAuthorization() async -> Bool
    #if os(watchOS)
    public func startWorkout()      // config.activityType 사용 (기존 .tennis 자리)
    public func pauseWorkout() / resumeWorkout()
    public func stopWorkout() async -> WorkoutResult?
    #endif
    public func formattedElapsed() -> String
}
```

앱에서의 사용:

```swift
// 골프 Watch 앱
@StateObject private var workout = WorkoutSessionService(
    configuration: .init(activityType: .golf)
)
// 테니스: .init(activityType: .tennis)
// 헬스: .init(activityType: .traditionalStrengthTraining, locationType: .indoor)
```

기존 `HealthKitService.shared` 호출부(앱 4파일 + 테스트 3파일)는 `@EnvironmentObject`/생성자 주입으로 전환. 로직은 불변.

### 2. ConnectivityCore (WC 전송) — 가장 까다로움

원칙: **패키지는 "무엇을 주고받는지 모른다."** 전송·폴백·콜드런치·staleness만 담당, 메시지 정의는 앱 몫.

```swift
public protocol ConnectivityMessage {
    static var messageType: String { get }   // 라우팅 키 (기존 "type" 필드)
    init?(from dictionary: [String: Any])
    func toDictionary() -> [String: Any]
}

public enum Delivery {
    case realtimeOnly   // sendMessage만, 미도달 시 드롭 — 기존 sendMetrics 경로
    case reliable       // sendMessage → transferUserInfo 폴백 — 기존 sendReliably
    case context        // sendMessage → updateApplicationContext — 기존 sessionStart 경로
}

public final class ConnectivityService: NSObject, ObservableObject {
    @Published public private(set) var isCounterpartReachable: Bool

    public init()
    public func send(_ message: some ConnectivityMessage, via delivery: Delivery)
    public func onReceive<M: ConnectivityMessage>(
        _ type: M.Type,
        maxAge: TimeInterval? = nil,     // sentAt 기준 staleness 필터
        handler: @escaping @MainActor (M) -> Void
    )
    public func clearSessionContext()
}
```

어렵게 잡은 버그 픽스들이 제너릭 규칙으로 승격된다:

- 코어가 모든 발신 메시지에 `sentAt` 자동 스탬프 → `isWorkoutEndStale`(60초)·`isSessionStartStale`(6시간) 하드코딩이 `onReceive(..., maxAge:)` 선언으로 일반화. sentAt 없는 구버전 메시지는 stale로 안 봄 (현행 규칙 유지 — 폰/워치 앱 버전 불일치 대비).
- 콜드런치 함정(활성화 직후 `receivedApplicationContext` 직접 읽기)은 코어 내부에서 처리 후 동일 라우팅으로 배달. 새 앱은 이 함정의 존재를 몰라도 됨.

테니스 마이그레이션 — 기존 메시지 struct는 앱에 남고 프로토콜만 채택, `@Published received*`는 앱 레벨 얇은 래퍼로:

```swift
extension ScoreState: ConnectivityMessage {
    static let messageType = "scoreState"
}

final class MatchConnectivity: ObservableObject {
    @Published var receivedScoreState: ScoreState?
    init(service: ConnectivityService) {
        service.onReceive(ScoreState.self) { [weak self] in self?.receivedScoreState = $0 }
        service.onReceive(SessionStartMessage.self, maxAge: 6 * 3600) { ... }
    }
}
```

골프 재사용 — "실시간은 필요 없고 전송만 되면 됨"이 정확히 `.reliable`:

```swift
struct RoundRecordMessage: ConnectivityMessage {
    static let messageType = "roundRecord"
    let courseName: String
    let holeScores: [Int]
    let endedAt: Date
}

// Watch: 폰이 꺼져 있어도 transferUserInfo 큐잉 → 다음 실행 때 배달
connectivity.send(RoundRecordMessage(...), via: .reliable)

// iPhone: 수신 → 저장
connectivity.onReceive(RoundRecordMessage.self) { record in
    try? roundStore.upsert(GolfRound(from: record))
}
```

### 3. PersistenceCore (SwiftData + CloudKit)

두 조각: **컨테이너 팩토리**(CloudKit 폴백)와 **제너릭 서비스**(fetch/upsert 패턴). `@Model` 클래스는 도메인이므로 각 앱에 잔류.

```swift
public enum PersistenceContainerFactory {
    /// CloudKit 동기화 시도 → 실패(iCloud 미로그인, 시뮬레이터 등) 시 로컬 폴백.
    /// 현 iOSApp.swift의 폴백 로직 이식 — 세 앱 모두 필요.
    public static func make(for types: [any PersistentModel.Type],
                            cloudKit: Bool = true) -> ModelContainer
}

@MainActor
public final class PersistenceService<Model: PersistentModel> {
    public init(context: ModelContext)
    public func fetchAll(sortBy: [SortDescriptor<Model>] = []) throws -> [Model]
    public func fetch(matching predicate: Predicate<Model>,
                      sortBy: [SortDescriptor<Model>] = []) throws -> [Model]
    /// replacing 조건의 기존 레코드를 지우고 삽입 (기존 workoutSessionId 중복 제거의 일반화)
    public func upsert(_ model: Model, replacing predicate: Predicate<Model>? = nil) throws
    public func delete(_ model: Model) throws
}
```

6월 검토의 "`#Predicate`가 타입별로 달라져 이득이 작다" 문제는 **predicate를 호출부가 넘기는 설계**로 해소:

```swift
// 테니스
let sid = match.workoutSessionId
try matchStore.upsert(match, replacing: #Predicate { $0.workoutSessionId == sid })

// 골프
@Model final class GolfRound {   // CloudKit 규칙: optional/기본값 + inverse 명시
    var courseName: String?
    var holeScores: [Int]?
    var endedAt: Date?
}
let container = PersistenceContainerFactory.make(for: [GolfRound.self])
let store = PersistenceService<GolfRound>(context: modelContext)
try store.upsert(round)
let history = try store.fetchAll(sortBy: [SortDescriptor(\.endedAt, order: .reverse)])
```

## 공수 산정 (2026-07-13 갱신)

전제: 점진적 추출, 각 단계 후 테니스 양 타겟 빌드+테스트 그린 유지.

| 단계 | 작업 | 공수 |
|---|---|---|
| 0 | `ralli-kit` 레포 생성 + 스캐폴딩, 테니스 양 타겟 로컬 링크 | 0.5일 |
| 1 | WorkoutCore 추출 + 테니스 마이그레이션 (싱글톤→DI 포함) | 1~1.5일 |
| 2 | ConnectivityCore 추출 + 테니스 마이그레이션 — **실기기 2대 회귀 필수** (시뮬레이터로 연동 버그 재현 불가) | 2~3일 |
| 3 | PersistenceCore 추출 (골프·헬스 확정으로 스킵하지 않음) | 1~1.5일 |
| | **합계** | **약 5~6.5일** |

진행 논리: **테니스가 첫 소비자로 패키지를 검증** (기존 테스트 스위트가 회귀 안전망) → 태그 후 골프 업데이트에서 2차 검증 → 헬스 앱은 처음부터 패키지 기반 신규 개발.

## SPM 채택 판단

이 상황("한 개발자가 iOS+watchOS 앱 3개에서 인프라 공유")은 SPM이 설계된 바로 그 용도로, 채택이 정석. 파일 복사 대비 진짜 장점:

- **접근제어가 경계를 강제** — 같은 타겟에선 `internal` 내부가 다 보이지만, 패키지는 `public` API만 계약이 됨. 도메인 코드의 인프라 침투를 컴파일러가 차단.
- **버그 픽스가 한 곳에** — 태그 하나로 세 앱에 전파.
- **순수 로직 테스트가 앱 빌드 없이 `swift test`로** 도는 안전망.

알고 시작할 마찰:

- 기능 하나가 패키지+앱에 걸치면 커밋/PR이 두 레포.
- Xcode 로컬 오버라이드는 편리하지만, 남겨두면 원격 태그가 조용히 무시됨 ("왜 최신 버전이 반영 안 되지?"의 단골 원인).
- HealthKit·WC의 실기기 검증 필요성은 패키지화로 사라지지 않음.

## 선행 리스크: 동기화 authority

`connectivity-sync-no-authority`(양방향 동기화 authority 부재)는 **패키지화로 해결되지 않는다** — "누가 점수의 주인인가"는 도메인 정책이라 앱 레이어에 남는다. 패키지는 전송만 담당. 동시 리팩터링하면 단계 2가 +2~3일이므로 별개 작업으로 분리 권장. 골프·헬스는 단방향(워치→폰)이라 이 문제 자체가 없다.
