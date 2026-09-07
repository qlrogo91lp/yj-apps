# W0 시작 유형 토글 — 구현 플랜

작성일: 2026-09-08
상태: **승인됨** (2026-09-08) · 구현 대기
선행 문서: [제품 스펙](../../../specs/shared/2026/2026-09-02-haruchi-fit-product-spec.md) W0절·5절 · [아키텍처](../../../specs/shared/2026/2026-09-02-haruchi-fit-architecture.md) D-M8
선행 작업: PR #12 (W2 요약) — **머지 완료** (`1ebe5c0`). 실기기 검증은 아직 남아 있다

**목표** — 홈에서 근력/유산소 중 무엇으로 시작할지 고르고, 그 선택을 기억한다.

**접근** — 새 상태를 만들지 않는다. 이미 있는 `mode` 가 `.idle` 일 때는 *시작 유형*, 세션 중에는
*현재 구간*을 뜻하게 한다. 값은 `UserDefaults` 에 rawValue 로 남기고 생성 시 읽는다.

---

## 전제 — 이 토글은 HealthKit 세션 타입을 바꾸지 않는다

**유산소로 시작해도 `HKWorkoutSession` 은 실내 근력으로 연다.** D-M8 이고, `WorkoutConfiguration.strength`
는 손대지 않는다. 이 토글이 정하는 것은 **앱이 소유한 첫 세그먼트의 종류**뿐이다.

이걸 헷갈려 `WorkoutConfiguration` 을 유형별로 나누면 2026-09-03 에 실측으로 닫은 문제가 되살아난다 —
HealthKit 은 카테고리가 다른 activityType 전환을 거부한다 (`Code=3 "Cannot add subactivity"`).

## 왜 `mode` 를 재사용하나

`startKind` 를 따로 두면 **세션 시작 시 두 값을 동기화해야 하고**, 어긋나면 화면에 보인 유형과 실제로
열린 구간이 달라진다. 지금 `start()` 가 `mode = .strength` 로 덮어쓰는 그 한 줄을 지우면 W0 에서 고른
값이 그대로 첫 구간이 된다. 상태가 하나면 어긋날 자리가 없다.

`.idle` 이 아닐 때 토글을 막는 가드가 이 재사용의 대가다. 진행 중 전환은 구간을 닫아야 하므로
`switchMode(to:)` 가 계속 맡는다.

---

## 파일

| 파일 | 할 일 |
|---|---|
| `Apps/HaruchiFit/watchosTests/Support/RecordFixture.swift` | **신규** — 테스트용 `WorkoutRecordMessage` 생성기. 두 스위트가 함께 쓴다 |
| `Apps/HaruchiFit/watchosTests/Workout/WorkoutViewModelTests.swift` | 수정 — 자체 `makeRecord` 를 fixture 로 교체 |
| `Apps/HaruchiFit/watchosTests/Workout/StartKindTests.swift` | **신규** — 기본값·토글·영속·가드 5개 |
| `Apps/HaruchiFit/WatchApp/Features/Workout/WorkoutViewModel.swift` | 수정 — `defaults` 주입, 생성 시 로드, `toggleStartKind()`, `start()` 에서 `mode` 덮어쓰기 제거 |
| `Apps/HaruchiFit/WatchApp/Features/Workout/Start/StartView.swift` | 수정 — 토글 행 + CTA 오렌지 고정 |
| `Apps/HaruchiFit/docs/specs/.../2026-09-07-haruchi-fit-roadmap.md` | 수정 — Phase 1 에서 W0 를 완료로 |
| `TODO.md` | 수정 — 하루치 행 갱신 |

토글 행은 **`StartView` 안의 private 계산 속성**으로 둔다. 그 화면에서만 쓰는 15줄이라 타입을
새로 만들 이유가 없다 (루트 `CLAUDE.md` 의 private helper 예외). 더 커지면
`Start/Components/` 로 뺀다.

---

## Task 1 — 시작 유형을 기억하고 토글한다

**Files:**
- Create: `Apps/HaruchiFit/watchosTests/Support/RecordFixture.swift`
- Modify: `Apps/HaruchiFit/watchosTests/Workout/WorkoutViewModelTests.swift`
- Create: `Apps/HaruchiFit/watchosTests/Workout/StartKindTests.swift`
- Modify: `Apps/HaruchiFit/WatchApp/Features/Workout/WorkoutViewModel.swift`

**Produces:** `WorkoutViewModel.toggleStartKind()` · `init(..., defaults: UserDefaults = .standard)`
· `RecordFixture.make(healthKitUUID:totalSeconds:)`

- [ ] **Step 1: 두 스위트가 공유할 fixture 를 만든다**

`WorkoutViewModelTests` 의 `makeRecord` 를 그대로 옮긴 것이다. 새 스위트도 `.summary` 로 보내려면
같은 값이 필요해 중복이 생긴다.

```swift
// watchosTests/Support/RecordFixture.swift
import Foundation
@testable import HaruchiFit_Watch_App

/// 테스트용 전송 페이로드. 두 스위트가 함께 쓴다.
enum RecordFixture {
    static func make(healthKitUUID: UUID? = UUID(),
                     totalSeconds: Int = 600) -> WorkoutRecordMessage
    {
        WorkoutRecordMessage(healthKitUUID: healthKitUUID,
                             startedAt: Date(timeIntervalSince1970: 0),
                             endedAt: Date(timeIntervalSince1970: TimeInterval(totalSeconds)),
                             totalSeconds: totalSeconds,
                             activeCalories: 412,
                             totalCalories: 520,
                             averageHeartRate: 128,
                             segments: [.init(kind: .strength, startOffset: 0, durationSeconds: totalSeconds)])
    }
}
```

- [ ] **Step 2: 기존 스위트를 fixture 로 옮긴다**

`WorkoutViewModelTests.swift` 에서 `private func makeRecord(...)` 정의를 **지우고**, 호출부
`makeRecord()` → `RecordFixture.make()`, `makeRecord(healthKitUUID: uuid, totalSeconds: 4344)` →
`RecordFixture.make(healthKitUUID: uuid, totalSeconds: 4344)` 로 바꾼다.

- [ ] **Step 3: 테스트가 여전히 통과하는지 확인 (리팩터링이므로 초록이 맞다)**

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
```

기대: `** TEST SUCCEEDED **`, 7개 통과. 여기서 깨지면 옮기다 흘린 것이다.

- [ ] **Step 4: 실패하는 테스트를 쓴다**

```swift
// watchosTests/Workout/StartKindTests.swift
import Foundation
@testable import HaruchiFit_Watch_App
import Testing

/// W0 — 홈에서 고른 시작 유형이 기억되고, 세션의 첫 구간이 그 유형으로 열린다.
@MainActor
struct StartKindTests {
    @Test("저장된 값이 없으면 근력으로 연다")
    func defaultsToStrength() {
        #expect(makeViewModel().mode == .strength)
    }

    @Test("토글하면 근력↔유산소가 번갈아 바뀐다")
    func toggleAlternates() {
        let viewModel = makeViewModel()

        viewModel.toggleStartKind()
        #expect(viewModel.mode == .cardio)

        viewModel.toggleStartKind()
        #expect(viewModel.mode == .strength)
    }

    @Test("토글한 유형은 다음 실행에서도 유지된다")
    func togglePersistsAcrossLaunches() {
        let defaults = freshDefaults()
        makeViewModel(defaults: defaults).toggleStartKind()

        #expect(makeViewModel(defaults: defaults).mode == .cardio)
    }

    @Test("저장된 값이 깨져 있으면 근력으로 연다")
    func brokenStoredValueFallsBack() {
        let defaults = freshDefaults()
        defaults.set("swimming", forKey: "startSegmentKind")

        #expect(makeViewModel(defaults: defaults).mode == .strength)
    }

    @Test("세션이 끝나지 않았으면 토글이 먹지 않는다")
    func toggleIgnoredOutsideIdle() {
        let viewModel = makeViewModel()
        viewModel.enterSummary(with: RecordFixture.make())

        viewModel.toggleStartKind()

        #expect(viewModel.mode == .strength)
    }

    // MARK: - Helpers

    /// 테스트마다 빈 저장소를 준다 — 하나가 남긴 값이 다음 테스트로 새면 순서에 의존하게 된다.
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "StartKindTests-\(UUID().uuidString)")!
    }

    private func makeViewModel(defaults: UserDefaults? = nil) -> WorkoutViewModel {
        WorkoutViewModel(connectivity: WorkoutRecordSendingSpy(),
                         remover: WorkoutRemovingSpy(),
                         defaults: defaults ?? freshDefaults())
    }
}
```

- [ ] **Step 5: 실패를 확인한다**

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
```

기대: **컴파일 에러** — `extra argument 'defaults' in call`, `value of type 'WorkoutViewModel' has no
member 'toggleStartKind'`. Swift 는 없는 API 를 컴파일 단계에서 막으므로 이게 정상적인 RED 다.

- [ ] **Step 6: 최소 구현**

`WorkoutViewModel.swift` 에 저장소를 주입하고 생성 시 읽는다.

```swift
    private let remover: WorkoutRemoving
    private let defaults: UserDefaults

    /// W0 에서 고른 시작 유형. 세션 사이에 남는다.
    private static let startKindKey = "startSegmentKind"
```

```swift
    init(session: WorkoutSessionService = WorkoutSessionService(configuration: .strength),
         connectivity: WorkoutRecordSending,
         remover: WorkoutRemoving = HealthKitWorkoutRemover(),
         defaults: UserDefaults = .standard)
    {
        self.session = session
        self.connectivity = connectivity
        self.remover = remover
        self.defaults = defaults

        // 저장된 값이 없거나 알아볼 수 없으면 근력으로 연다.
        mode = SegmentKind(rawValue: defaults.string(forKey: Self.startKindKey) ?? "") ?? .strength
```

토글을 추가한다. `switchMode(to:)` 바로 위에 둔다 — 둘의 차이가 눈에 들어와야 한다.

```swift
    /// W0 — 시작 유형을 근력↔유산소로 돌린다. 종류가 2개뿐이라 피커도 화살표도 두지 않는다
    /// (제품 스펙 W0). 선택은 다음 실행까지 남는다.
    ///
    /// **세션이 열린 뒤에는 이 경로를 쓰지 않는다.** 진행 중 전환은 구간을 닫아야 하므로
    /// `switchMode(to:)` 가 맡는다.
    func toggleStartKind() {
        guard phase == .idle else { return }
        mode = mode == .strength ? .cardio : .strength
        defaults.set(mode.rawValue, forKey: Self.startKindKey)
        WKInterfaceDevice.current().play(.click)
    }
```

`start()` 에서 **`mode = .strength` 줄을 지운다.** 그 자리에 주석을 남긴다.

```swift
    func start() {
        session.startWorkout()
        phase = .active
        WKInterfaceDevice.current().play(.start)
        // mode 는 W0 에서 고른 값 그대로다 — 첫 구간이 그 유형으로 열린다.
        // 세션 자체는 유형과 무관하게 실내 근력이다 (D-M8).
        closedSegments = []
        openSegmentStart = 0
        startedAt = Date()
    }
```

- [ ] **Step 7: 통과를 확인한다**

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
```

기대: `** TEST SUCCEEDED **`, **12개 통과** (기존 7 + 신규 5).

- [ ] **Step 8: 커밋**

```bash
git add Apps/HaruchiFit/WatchApp/Features/Workout/WorkoutViewModel.swift Apps/HaruchiFit/watchosTests
git commit -m "✨ 시작 유형을 기억하고 첫 구간을 그 유형으로 연다 (W0)"
```

---

## Task 2 — 홈 화면에 토글 행을 붙인다

**Files:**
- Modify: `Apps/HaruchiFit/WatchApp/Features/Workout/Start/StartView.swift`

**Consumes:** Task 1 의 `viewModel.toggleStartKind()` · `viewModel.mode`

뷰는 테스트하지 않는다 (앱 `CLAUDE.md`). 확인은 프리뷰와 실기기다.

- [ ] **Step 1: `StartView` 를 바꾼다**

```swift
/// W0 — 시작 유형 토글까지. 잔디와 오늘 요약은 후속 플랜이다.
struct StartView: View {
    @ObservedObject var viewModel: WorkoutViewModel

    var body: some View {
        VStack(spacing: 10) {
            Text("Haruchi Fit")
                .font(.headline)
                .foregroundStyle(Color.brandOrange)

            Button("운동 시작") { viewModel.start() }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandOrange)

            startKindToggle
        }
    }

    /// 유형 선택 화면을 토글 한 줄로 흡수했다 — 2개뿐이라 피커가 불필요하고 화살표도 두지 않는다.
    /// **CTA 색은 오렌지 고정**이고, 유형 구분은 이 텍스트 색으로만 한다 (제품 스펙 W0).
    private var startKindToggle: some View {
        Button { viewModel.toggleStartKind() } label: {
            HStack {
                Text("시작 운동")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.mode.title)
                    .foregroundStyle(viewModel.mode == .strength ? Color.brandOrange : .blue)
            }
            .font(.system(size: 14))
        }
        .buttonStyle(.plain)
    }
}
```

`.tint(Color.brandOrange)` 는 새로 붙는다 — 지금 CTA 는 시스템 기본 강조색이라 스펙의
"CTA 색은 오렌지 고정"과 어긋나 있다.

- [ ] **Step 2: 빌드로 확인한다**

```bash
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFit Watch App" -destination "id=$WATCH" build
```

기대: `** BUILD SUCCEEDED **`

- [ ] **Step 3: 커밋**

```bash
git add Apps/HaruchiFit/WatchApp/Features/Workout/Start/StartView.swift
git commit -m "✨ 홈에 시작 유형 토글 행을 붙인다 (W0)"
```

---

## Task 3 — 문서 갱신

**Files:**
- Modify: `Apps/HaruchiFit/docs/specs/shared/2026/2026-09-07-haruchi-fit-roadmap.md`
- Modify: `TODO.md`

- [ ] **Step 1: 로드맵**

"완료된 것" 표에 행을 더한다.

```
| **W0 시작 유형 토글** | PR #NN — 마지막 선택을 UserDefaults 에 기억. 세션 타입은 근력 고정(D-M8) |
```

Phase 1 표에서 W0 행을 지우고 남은 WC 를 1번으로 당긴다. "남은 13개" → "남은 12개".
이후 Phase 의 번호도 하나씩 당긴다.

- [ ] **Step 2: TODO**

하루치 표의 W0 행을 `~~취소선~~` + `완료 (PR #NN)` 으로 닫고, WC 를 **다음**으로 표시한다.

- [ ] **Step 3: 커밋**

```bash
git add TODO.md Apps/HaruchiFit/docs
git commit -m "📝 W0 완료를 로드맵·TODO 에 반영한다"
```

---

## 검증

```bash
IOS=$(.github/scripts/pick-simulator.sh iOS '^iPhone')
WATCH=$(.github/scripts/pick-simulator.sh watchOS '^Apple Watch')

xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFitWatchTests" -destination "id=$WATCH" test
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiFit" -destination "id=$IOS" build
xcodebuild -workspace YJApps.xcworkspace -scheme "HaruchiComplicationExtension" -destination "id=$WATCH" build
make lint && make format
```

`WorkoutCore` 를 건드리지 않으므로 GolfCounter·Ralli 회귀 빌드는 불필요하다.

> **`make format` 은 CI 와 같은 버전으로 돌린다.** 로컬 swiftformat 이 CI 핀(0.61.1)보다 낮으면
> 새 규칙 위반이 로컬에서만 통과한다 — 2026-09-07 에 `blankLinesAroundMark` 로 실제로 겪었다.
> `swiftformat --version` 을 `.github/workflows/ci.yml` 의 `SWIFTFORMAT_VERSION` 과 대조할 것.

### 실기기 (필수)

햅틱은 시뮬레이터에서 재현되지 않는다 (제품 스펙 5절).

- [ ] 토글을 탭하면 근력↔유산소가 바뀌고 **`.click` 햅틱**이 난다
- [ ] 유산소로 두고 앱을 껐다 켜면 **유산소로 열린다**
- [ ] 유산소로 시작 → W1 상단 라벨이 `진행 중 · 유산소` 다
- [ ] 유산소로 시작 → 전환 없이 종료 → **요약 바가 전부 파란색**이고 `유산소 N분` 만 뜬다
- [ ] 건강 앱에서 그 워크아웃이 **근력 운동으로** 기록돼 있다 (D-M8 — 의도된 동작이다)

---

## 스코프 밖

잔디·오늘 요약(02 홈) · 컴플리케이션(WC) · 유형별 CTA 색 변경 · iOS 쪽 표시.
