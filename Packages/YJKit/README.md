# RalliKit

Ralli(테니스 카운터)에서 추출한 iOS+watchOS 워크아웃 앱 인프라. 독립 라이브러리를 필요한 것만 골라 의존한다.

| Product | 역할 | 상태 |
|---|---|---|
| `WorkoutCore` | HealthKit 워크아웃 세션·칼로리·심박 측정 | ✅ |
| `ConnectivityCore` | 폰↔워치 전송 (실시간/큐잉/컨텍스트) | ✅ |
| `PersistenceCore` | SwiftData + CloudKit 컨테이너/서비스 | ✅ |

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
- `stopWorkout()`은 `WorkoutResult`(시간·칼로리·평균심박) 반환.
- 테스트·프리뷰에서는 `#if DEBUG` 전용 `setLiveMetricsForTesting(heartRate:calories:elapsedSeconds:)`로 표시 값 주입.

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

- 로컬 개발: 소비자 앱 Xcode 프로젝트에 **Add Local…** 로 이 폴더를 추가하면 원격 참조를 오버라이드한다.
  ⚠️ 로컬 오버라이드를 남겨두면 원격 태그가 조용히 무시된다 — 검증 후 제거할 것.
- 배포: 초기에는 `branch: "main"` 참조, 앱 스토어 릴리즈 시점에 semver 태그.
