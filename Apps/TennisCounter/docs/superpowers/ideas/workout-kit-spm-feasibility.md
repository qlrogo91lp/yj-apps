# WorkoutKit SPM 추출 타당성 검토

- 작성일: 2026-06-29
- 상태: **사전 검토 (Feasibility)** — 구현 결정 전, 미커밋
- 동기: 향후 별도 "헬스 기록용 앱"에서 운동 중 칼로리 측정(HealthKit) · 저장(SwiftData) · 폰↔워치 동기화(WatchConnectivity)를 재사용하고 싶음. 현재 `Shared/Services/`의 세 서비스를 SPM 패키지로 분리할 수 있는지 가능성 판단.

## 결론

**가능하다. 단 "셋 다 통째로"가 아니라 "도메인 무관 제너릭 코어만" 추출한다.**

세 서비스는 테니스 도메인(`Match`, `MatchOptions`, 점수/세트)에 묶인 정도가 천차만별이라 재사용성이 다르다.

| 서비스 | 규모 | 재사용성 | 근거 |
|--------|------|---------|------|
| `HealthKitService` | 221줄 | ★★★ 거의 그대로 | 테니스 의존성이 `config.activityType = .tennis` 한 줄뿐. 워크아웃 세션 생명주기·칼로리/심박 수집·타이머·포맷팅 전부 도메인 무관 |
| `WatchConnectivityService` | 413줄 | ★ 절반만 | 전송 계층(`sendReliably`/`transferUserInfo` 폴백/델리게이트/콜드런치 staleness 처리)은 제너릭하고 가치 큼. 메시지 타입(`SessionStartMessage`/`ScoreState`/`MatchEndMessage`...)은 100% 테니스 |
| `MatchPersistenceService` | 55줄 | ★★ 패턴만 | `configure(ModelContext)`+`fetchAll`/`upsert` 패턴은 제너릭하나 `Match` @Model 타입에 묶임. 타입이 아니라 *패턴*만 재사용 |

## 권장 패키지 경계

도메인 코드와 인프라 코드를 가른다. 패키지에는 "무엇을 주고받는지 모르는 제너릭 코어"만 둔다.

### 1. HealthKit — 가장 깔끔한 후보 (SPM 1순위)
```swift
func startWorkout(activityType: HKWorkoutActivityType = .other)
```
`.tennis` 하드코딩만 파라미터화하면 끝. 테니스든 헬스 기록이든 그대로 사용.

### 2. WatchConnectivity — 전송 코어 / 도메인 메시지 분리
- **패키지**: `WCSession` 활성화, `sendReliably`, `transferUserInfo` 폴백, WCSessionDelegate, **콜드런치 staleness 처리**(`isWorkoutEndStale`/`isSessionStartStale`/`receivedApplicationContext` 직접 읽기). → 어렵게 잡은 버그 픽스들이라 재사용 가치 최고. 새 앱에서 다시 만들면 같은 버그가 또 터진다.
- **앱**: `[String: Any]` ↔ 도메인 타입 변환(`toDictionary()`/`init?(from:)`)은 앱에 잔류. 패키지는 `protocol WCMessage { func toDictionary() }` 정도만 노출.

### 3. Persistence — 제너릭/프로토콜 (우선순위 낮음)
```swift
final class PersistenceService<T: PersistentModel> { ... }
```
`Match` 자체는 안 가져가고 패턴만. SwiftData `#Predicate` 제약(`fetchByWorkoutSession`의 predicate가 타입별로 달라짐) 때문에 이득이 가장 작다. **초기엔 추출하지 않는 것을 권장.**

### 권장 범위
> **`WorkoutKit`(가칭): HealthKit 측정 + WC 전송 코어만.** Persistence·도메인 메시지·`Match` 저장은 각 앱에 둔다.

## SPM 실무 체크 (전부 통과)

- HealthKit / WatchConnectivity / SwiftData 모두 SPM 패키지에서 import 가능. `Package.swift`에 `platforms: [.iOS(...), .watchOS(...)]` 명시.
- 현재의 `#if os(watchOS)` 분기 그대로 동작.
- ⚠️ **엔타이틀먼트·Info.plist usage description**(HealthKit 권한 문구, CloudKit, WC capability)은 패키지가 아니라 **앱 타겟에 잔류.** 패키지는 코드만 제공.
- ⚠️ 현재 셋 다 `static let shared` 싱글톤 → 패키지화 시 인스턴스 주입(DI)형으로 전환 권장. 테스트 용이성도 같이 상승.
- 호출부 영향 범위(싱글톤 참조): 앱 4파일(`iOSApp`, `WatchApp`, iOS/Watch `WorkoutSessionViewModel`, Watch `HomeView`/`WorkoutMetricsView`) + 테스트 3파일.

## 선행 리스크: 동기화 authority

WC를 추출하면서 `connectivity-sync-no-authority`(양방향 동기화 authority 부재) 문제가 싱글톤 구조와 얽혀 있음. 추출 시 같이 정리할지 / 현 구조 그대로 패키징할지 결정 필요. **현 동기화 로직을 그대로 패키지로 옮기면 같은 구조적 약점도 함께 이식된다는 점 유의.**

---

## 공수 산정

전제: 점진적 추출(한 번에 하나씩, 각 단계 후 양 타겟 빌드+테스트 그린 유지). 실기기 2대 통합 검증 포함.

| 단계 | 작업 | 공수 | 비고 |
|------|------|------|------|
| 0. 패키지 스캐폴딩 | local SPM 패키지 생성, `Package.swift` 플랫폼/타겟 설정, 두 앱 타겟에 링크 | **0.5일** | 빈 패키지가 양 타겟에서 빌드되는 것까지 |
| 1. HealthKit 추출 | `activityType` 파라미터화, 파일 이동, 호출부(워크아웃 시작) 수정, 싱글톤→DI | **1~1.5일** | 도메인 의존 없어 가장 안전. 실기기 칼로리/심박 측정 검증 포함 |
| 2. WC 전송 코어 분리 | 도메인 메시지 struct를 앱에 남기고 전송/델리게이트/staleness만 패키지로, `WCMessage` 프로토콜 설계 | **2~3일** | 가장 까다로움. 콜드런치/staleness 회귀 위험. 실기기 2대 통합 테스트 필수 |
| 3. (선택) Persistence 제너릭화 | `PersistenceService<T>` + predicate 추상화 | **1~2일** | 이득 작음. 초기 스킵 권장 |
| 4. DI 전환 마감 | 잔여 `*.shared` 호출부(앱 4 + 테스트 3) 정리, 테스트 보정 | **0.5~1일** | 1·2 진행 중 분산 처리되면 축소 |

- **최소 범위(HealthKit + WC 코어, 권장):** **약 4~6일(1인 기준)**
- **전체(Persistence 포함):** **약 5~8일**

### 공수를 키우는 변수
- **동기화 authority 동시 리팩터링** 여부 — 같이 하면 WC 단계가 +2~3일. 별개 권장.
- **실기기 통합 검증** — `watch-sync-simulator-trap`(시뮬레이터로 연동 버그 재현 불가) 때문에 단계 2는 실기기 2대 회귀 테스트가 공수에 반드시 포함되어야 함.
- **CloudKit/엔타이틀먼트 재배선** — 앱 타겟 capability 점검 0.5일 여유.

### 권장 진행 방식
HealthKit(단계 0+1)만 먼저 빼서 새 앱 만들 때 실전 검증 → 효용 확인 후 WC 코어(단계 2) 착수. WC는 위험 대비 이득을 새 앱 요구사항이 구체화된 뒤 재평가.
