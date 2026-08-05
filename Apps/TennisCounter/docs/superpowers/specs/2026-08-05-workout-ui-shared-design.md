# WorkoutUI 공유 화면 설계 — 세 앱 공통 워크아웃 메트릭/컨트롤

- 작성일: 2026-08-05
- 상태: 설계 확정 (구현 착수 전)
- 선행 문서: [[../ideas/workout-kit-spm-feasibility.md]] (소비자 3앱 확정), [[../logs/2026-07-16-rallikit-spm-extraction-status.md]] (Plan 1·2·3 완료 현황)

## 목표

테니스(Ralli)·골프 카운터·헬스 기록 세 앱이 **동일한 워크아웃 화면·동일한 항목**을 쓴다.
RalliKit에 UI product(`WorkoutUI`)를 신설하고, 테니스 앱을 1차 소비자로 마이그레이션한다.

같은 화면이려면 같은 숫자여야 한다. 조사 중 두 플랫폼이 같은 라벨로 다른 숫자를
보여주는 문제와, iOS pause가 로컬에만 적용되는 버그를 발견했다 — 이 설계는 UI 추출과
함께 그 동작 통일까지 포함한다.

## 확정 결정 사항

| 결정 | 내용 |
|---|---|
| 통일 범위 | 플랫폼별 화면 1개씩(Watch/iOS), 세 앱이 공유. Watch·iOS 간 레이아웃은 다르게 유지 |
| 표시 항목 | **4개 고정: 경과시간·활동 kcal·총 kcal·BPM.** 걸음수·거리 제외(의미 없음), iOS "경기 수" 카드 제거 |
| 칼로리 기준 | **워크아웃 누적**(시작~현재)으로 통일. 기존 iOS의 "경기 구간 델타" 표시는 폐기 |
| 데이터 입력 | 화면은 순수 값 타입 `WorkoutMetrics`를 받는다 (접근법 A). 서비스·ViewModel을 모름 |
| 라벨 | 패키지가 소유 (SPM 리소스 + `Bundle.module`, en/ko). 호출부 주입 아님 |
| 색상 | 패키지에 하드코딩 (노랑 타이머·빨강 하트·초록/노랑 링). 테마 주입은 YAGNI — 필요해질 때 Environment로 |
| pause 동기화 | **신규 구현** (기존엔 미동기화 버그). 폰 pause → 워치 HK 세션 실제 정지 |
| 경과시간 | 워치가 단일 소스. 앵커 동기화 + 폰 로컬 보간 |
| 워크아웃 메시지 위치 | **`WorkoutCore`** (신규 의존: WorkoutCore → ConnectivityCore). ConnectivityCore의 "코어는 메시지를 모른다" 계약은 유지 |
| macOS | 고려하지 않음 (platforms 선언은 건드리지 않되 검증 대상 아님) |

## 배경: 발견된 기존 버그·불일치

1. **같은 라벨, 다른 숫자** — Watch 메트릭 화면은 워크아웃 누적 칼로리(`currentCalories`),
   iOS는 경기 구간 델타(`currentCalories - kcalAtStart`)를 표시. 워크아웃 중 두 번째
   경기를 시작하면 iOS 수치만 0 근처로 리셋된다.
2. **pause 미동기화** — pause 관련 ConnectivityMessage가 없다. 워치 pause는 진짜
   `HKWorkoutSession`을 멈추지만 폰은 모른다. 폰 pause는 **로컬 Timer만** 멈춘다 —
   HealthKit 세션은 계속 돌고, 이후 두 기기의 경과시간이 영구히 어긋난다.
3. **경기 사이 수치 동결** — 워치 `broadcastMetrics()`가 `guard case .playing`이라
   모드 선택·결과 화면에 있는 동안 폰 수치가 멈춘다.
4. **iOS는 워치 elapsed를 버림** — 메트릭 수신 시 `elapsedSeconds`를 자기 로컬 타이머
   값으로 덮어쓴다 (`WorkoutSessionViewModel.swift:75`). 두 시계는 완전히 독립.
5. **데드코드** — `WatchApp/Features/Workout/Metrics/Components/WorkoutMetric.swift`는
   참조 0건. 삭제 대상.

## 아키텍처

### 패키지 구조 (ralli-kit)

```
ralli-kit/
├── Package.swift                       # defaultLocalization: "en" 추가, WorkoutUI product 추가
├── Sources/
│   ├── WorkoutCore/                    # 기존 + 추가분
│   │   ├── WorkoutSessionService.swift # (기존, 변경 없음)
│   │   ├── WorkoutConfiguration.swift  # (기존, 변경 없음)
│   │   ├── WorkoutResult.swift         # (기존, 변경 없음)
│   │   ├── WorkoutMetrics.swift        # ★ 신규 — 앱에서 승격한 값 타입
│   │   ├── WorkoutAnchor.swift         # ★ 신규 — 경과시간 앵커 + 보간 계산
│   │   └── Messages/
│   │       ├── WorkoutMetricsMessage.swift  # ★ 신규 — 워치→폰 상태 브로드캐스트
│   │       └── WorkoutPauseMessage.swift    # ★ 신규 — 폰→워치 pause/resume 명령
│   ├── WorkoutUI/                      # ★ 신규 product (의존: WorkoutCore)
│   │   ├── Shared/                          # 두 플랫폼 공용 컴포넌트
│   │   │   ├── HeartRateIcon.swift          # 펄스 애니메이션 (iOS·Watch 중복 통합)
│   │   │   └── MetricValueLabel.swift       # "245 kcal" 수치+단위 타이포
│   │   ├── Watch/                           # #if os(watchOS)
│   │   │   ├── WorkoutMetricsView.swift     # 세로 4항목
│   │   │   ├── WorkoutControlsView.swift    # pause/resume·종료 버튼
│   │   │   └── Components/
│   │   │       └── StackedLabel.swift       # 공백 split 세로 라벨 (이동)
│   │   ├── iOS/                             # #if os(iOS)
│   │   │   ├── WorkoutDashboardView.swift   # 타이머 링 + 2×2 그리드 + 컨트롤
│   │   │   └── Components/
│   │   │       ├── MetricCard.swift         # 카드 컨테이너 (이동)
│   │   │       ├── WorkoutTimerRing.swift   # 링 (이동)
│   │   │       └── WorkoutControls.swift    # pause/end 버튼 쌍
│   │   └── Resources/
│   │       ├── en.lproj/Localizable.strings # ACTIVE KCAL, TOTAL KCAL, BPM, Pause…
│   │       └── ko.lproj/Localizable.strings
│   ├── ConnectivityCore/               # 변경 없음
│   └── PersistenceCore/                # 변경 없음
```

**플랫폼 폴더 분리 규칙**

- `Shared/`는 두 플랫폼이 함께 쓰는 컴포넌트만. `Watch/`·`iOS/`는 서로 import하지 않는다
  (테니스 앱의 계층형 Components 규칙과 같은 원칙).
- **폴더 분리는 조직화일 뿐 컴파일 분리가 아니다.** SPM은 타겟 내 모든 파일을 모든
  플랫폼에 대해 컴파일하므로, `Watch/`·`iOS/` 아래 파일은 **파일 단위로 `#if os(watchOS)` /
  `#if os(iOS)`로 감싼다.** 이러면 플랫폼 전용 API 오용이 빌드 타임에 걸리고, 각 플랫폼에
  불필요한 코드가 안 들어간다.
- 타겟을 둘로 쪼개는 방식(`WorkoutUIWatch`/`WorkoutUIPhone`)은 진짜 컴파일 분리를 주지만
  product가 늘고 Xcode 수동 링크 단계가 타겟마다 추가된다 — 이번 규모엔 과하므로 기각.
- 내부 의존 추가 2건: `WorkoutUI → WorkoutCore`, `WorkoutCore → ConnectivityCore`.
  "세 코어는 서로 의존 없음" 원설계에서 이탈하지만, 세 소비자 앱이 모두 두 코어를
  함께 쓰므로 실질 비용 없음.
- 워크아웃 메시지를 `ConnectivityCore`가 아닌 `WorkoutCore`에 두는 이유:
  ConnectivityCore의 계약("코어는 무엇을 주고받는지 모른다 — 메시지 정의는 소비자 몫")을
  유지하기 위해. 여기서 소비자는 앱이 아니라 WorkoutCore다. 도메인 메시지(Score·Match)는
  기존대로 앱에 잔류한다.

### WorkoutMetrics (WorkoutCore 승격)

```swift
public struct WorkoutMetrics: Equatable, Sendable {
    public let elapsedSeconds: TimeInterval
    public let activeCalories: Double   // 기존 `calories` — 누적/델타 혼선의 원인이라 개명
    public let totalCalories: Double    // 활동 + 휴식(basal)
    public let heartRate: Double
    public var formattedElapsed: String
}
```

- 앱의 `Shared/Models/WorkoutMetrics.swift`는 삭제. 와이어 직렬화(`toDictionary`/`init?(from:)`)는
  `WorkoutMetricsMessage`가 흡수한다 (아래).
- `WorkoutSessionService.formattedElapsed()`와 앱의 `formatSeconds` 중복은 이 타입의
  `formattedElapsed` 하나로 수렴.

### 경과시간 — 앵커 동기화 + 로컬 보간

시간 "값"을 스트리밍하지 않고 **기준점**을 동기화한다. 워치가 보내는 앵커는
`(elapsedSeconds, isPaused)` — 모든 메시지에 자동 스탬프되는 `sentAt`(Plan 2)과 결합해
폰이 매초 로컬 계산한다:

```
elapsed = 받은 elapsedSeconds + (isPaused ? 0 : now - sentAt)
```

- 워치 `WorkoutCore.elapsedSeconds`는 틱 카운터라 변경 불필요 — 이미 노출된 값을 그대로 실음
- 드리프트 누적 없음 — 매 메시지 수신마다 리셋
- 메시지 유실돼도 다음 앵커로 자동 복구, 폰 백그라운드 복귀 시 재계산만으로 즉시 정확
- 이 계산식은 `WorkoutAnchor`(WorkoutCore)의 순수 함수로 둔다 — 세 앱이 같은 식을 강제받는다
- 폰의 자체 시간 관리(`startTimer`의 `Date` 계산·`totalPausedSeconds`·`pausedAt`)는 삭제.
  1초 화면 갱신용 틱만 남고, 값은 전부 앵커 기반

### 신규 메시지 (WorkoutCore/Messages/)

| 메시지 | 방향 | 경로 | 페이로드 |
|---|---|---|---|
| `WorkoutMetricsMessage` | 워치→폰 | `.realtimeOnly` | `elapsedSeconds`, `isPaused`(신규 키), `activeCalories`, `totalCalories`, `heartRate` |
| `WorkoutPauseMessage` | 폰→워치 | `.reliable` (큐잉) | `sessionId`, `shouldPause: Bool` |

- `WorkoutMetricsMessage`는 기존 metrics 딕셔너리의 확장 — 신규 키는 additive라
  구버전 폰은 무시한다. **구버전 워치가 보낸 페이로드의 폴백 로직(`totalCalories` 없으면
  `calories`로)은 그대로 이식한다.**
- 전송 조건 완화: `guard case .playing` 제거 → **워크아웃 활성 동안 항상** 브로드캐스트.
  칼로리는 델타 계산 없이 누적 원시값을 그대로 실음.

### pause 동기화 흐름

```
폰 pause 버튼
  → WorkoutPauseMessage(.reliable) 전송        # 폰 isPaused는 아직 안 바꿈
  → 워치 수신 → healthKit.pauseWorkout()        # 진짜 HK 세션 정지
  → isPaused=true가 다음 WorkoutMetricsMessage에 실려 폰 도착
  → 폰 isPaused 갱신 (ack 기반)
```

- **폰은 낙관적 토글을 하지 않는다.** pause 메시지를 모르는 구버전 워치면 아무 일도
  일어나지 않고 폰 UI도 안 바뀐다 — 오동작 대신 무동작. (버튼 로딩 표시는 UI 재량)
- resume도 같은 메시지(`shouldPause: false`)로 왕복.
- 워치에서 누른 pause는 기존대로 즉시 로컬 적용되고, 앵커를 타고 폰에 전파된다.
- 폰 단독(워치 미연결): `watchConnected == false`면 pause 버튼 비활성화.
  워치 없이 시작한 워크아웃(HK 세션 없는 로컬 모드)은 기존 동작 유지.

### 화면 API — 순수 입력, 콜백 출력

```swift
public struct WorkoutDashboardView: View {   // iOS
    public init(metrics: WorkoutMetrics,
                isPaused: Bool,
                isPauseAvailable: Bool,      // 폰: watchConnected, 워치: 항상 true
                onPauseResume: @escaping () -> Void,
                onEnd: @escaping () -> Void)
}
// WorkoutMetricsView(Watch): metrics + isPaused만
// WorkoutControlsView(Watch): isPaused + 콜백 2개
```

앵커 계산·메시지 송수신은 앱 ViewModel 몫, 화면은 결과만 그린다.
네이밍은 프로젝트 컨벤션(화면 = View suffix) 유지.

## 칼로리 기준 변경의 저장 데이터 영향 (회귀 위험 ★)

누적 전송으로 바꾸면 iOS 폰 드라이버 저장 경로가 틀어진다. 현재:

```swift
session.kcalAtStart = 0                    // WorkoutSessionViewModel.swift:176
session.kcalAtEnd = metrics.calories       // :204 — 지금은 "델타"라 우연히 맞음
match.caloriesBurned = kcalAtEnd - kcalAtStart   // :307
```

`metrics`가 누적이 되면 `누적 - 0 = 워크아웃 전체 칼로리`가 경기 기록에 저장된다.

**수정**: 경기 시작 시점에 기준값을 캡처한다 — `session.kcalAtStart = metrics.activeCalories`
(totalKcalAtStart 동일). 워치의 기준값 캡처 방식과 대칭이 되고 저장 뺄셈 로직은 무변경.
워치발 저장 경로(`MatchEndMessage`)는 세션 자체 기준값으로 델타를 계산하므로 영향 없음.

**이 회귀를 재현하는 테스트를 먼저 작성한 뒤 수정한다** (버그 수정 규칙).

## 테니스 앱 마이그레이션

### 삭제

- Watch: `Features/Workout/Metrics/`·`Features/Workout/Controls/` 전체 (데드코드
  `WorkoutMetric.swift` 포함), 관련 로컬라이즈 키(`metrics_*`, `workout_pause` 등 → 패키지로)
- iOS: `Features/Workout/` 전체 (`WorkoutTabView` + Components 5개)
- 공용: `Shared/Models/WorkoutMetrics.swift`

### 교체

- Watch `WorkoutSessionView`: 컨트롤 탭(tag 0)·메트릭 탭(tag 2)을 패키지 View로. 부모가 `healthKit`을 관찰해
  `WorkoutMetrics` 값으로 변환 후 내려줌 (기존: 화면이 서비스 직접 관찰)
- iOS `WorkoutSessionView`: `WorkoutTabView` 호출부를 `WorkoutDashboardView`로
- iOS `WorkoutSessionViewModel`: 앵커 기반 시간 + pause 왕복 + `kcalAtStart` 캡처
- Watch `WorkoutSessionViewModel`: 브로드캐스트 조건 완화 + 델타 계산 제거 +
  `WorkoutPauseMessage` 수신 처리

## 테스트

**ralli-kit**
- `WorkoutMetrics.formattedElapsed` 포맷 경계 (시간 자리올림)
- `WorkoutAnchor` 보간 순수 함수: 진행 중·pause 동결·sentAt 경계
- 신규 메시지 직렬화 왕복 + 구버전 폴백 (기존 `WorkoutMetricsTests` 이식)

**테니스 앱**
- 칼로리 회귀 재현 테스트 (수정 전 작성): 누적 전송 시 `Match.caloriesBurned`가
  경기 구간 델타로 저장되는지
- pause 왕복: 요청 후 낙관적 토글 없음 → 앵커 수신 시에만 `isPaused` 갱신 →
  구버전 워치(무응답) 시나리오
- View는 테스트하지 않음 (프리뷰 확인)

## 실행 순서 (각 단계가 독립 빌드·롤백 단위)

1. **ralli-kit**: `WorkoutMetrics`·`WorkoutAnchor`·메시지 2종 (WorkoutCore) →
   `WorkoutUI` 타겟·리소스 → 컴포넌트·View 3개 이식
2. **테니스 스왑**: Xcode GUI로 `WorkoutUI`를 iOS·Watch 타겟에 링크 (사용자 수동,
   pbxproj 자동 편집 금지) → 앱 파일 삭제·호출부 교체 → 로컬라이즈 키 정리
3. **동작 변경** (2와 커밋 분리): 칼로리 누적 전송 + `kcalAtStart` 캡처 수정 →
   앵커 기반 시간 → pause 동기화
4. **검증**: 신규/변경 타겟 Debug+Release 빌드 (Plan 1 교훈) + 실기기 2대 회귀에
   pause 왕복·경기 사이 수치 갱신 추가
5. **문서**: ralli-kit README에 `## WorkoutUI 사용법` 섹션 — View 시그니처,
   소비자 책임(앵커 계산 호출·메시지 라우팅 등록), pause 규약, 리소스 주의.
   기존 README의 소비자 가이드 패턴을 따른다. 마이그레이션 이력·결정 근거는
   본 문서(테니스 레포)에 남긴다

## 스코프 밖

- 테마/브랜드 색 주입 (필요 시 Environment로 후속)
- 걸음수·거리 표시 (수집 인프라는 WorkoutCore에 이미 있음 — 표시하지 않기로 결정)
- 로컬 → 원격 패키지 참조 전환 (릴리즈 체크리스트의 별도 항목)
- 골프·헬스 앱 적용 (각 앱 세션에서 ralli-kit README를 소비자 가이드로 사용)
- iOS Live Activity·Complication (기존 동작 유지, 이번 범위 아님)
