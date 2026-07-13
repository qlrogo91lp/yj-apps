# RalliKit

Ralli(테니스 카운터)에서 추출한 iOS+watchOS 워크아웃 앱 인프라. 독립 라이브러리를 필요한 것만 골라 의존한다.

| Product | 역할 | 상태 |
|---|---|---|
| `WorkoutCore` | HealthKit 워크아웃 세션·칼로리·심박 측정 | ✅ |
| `ConnectivityCore` | 폰↔워치 전송 (실시간/큐잉/컨텍스트) | 예정 |
| `PersistenceCore` | SwiftData + CloudKit 컨테이너/서비스 | 예정 |

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

## 소비자 앱 체크리스트 (패키지가 대신 못 해주는 것)

- [ ] 타겟 Capability에 **HealthKit** 추가 (엔타이틀먼트)
- [ ] Info.plist에 `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription` 문구
- [ ] watchOS 타겟 최소 버전 10.0, iOS 17.0

## 개발 워크플로

- 로컬 개발: 소비자 앱 Xcode 프로젝트에 **Add Local…** 로 이 폴더를 추가하면 원격 참조를 오버라이드한다.
  ⚠️ 로컬 오버라이드를 남겨두면 원격 태그가 조용히 무시된다 — 검증 후 제거할 것.
- 배포: 초기에는 `branch: "main"` 참조, 앱 스토어 릴리즈 시점에 semver 태그.
