import Combine
import ConnectivityCore
import Foundation
import WatchKit
import WorkoutCore

/// 워치 워크아웃 세션의 소유자.
/// `WorkoutSessionService` 는 싱글톤이 아니므로 앱 루트에서 한 번 만들어 주입한다 (YJKit README).
@MainActor
final class WorkoutViewModel: ObservableObject {
    @Published private(set) var isPaused = false
    @Published private(set) var metrics = WorkoutMetrics()
    /// 현재 구간. **HealthKit 은 이 전환을 모른다** — 근력↔유산소처럼 카테고리가 다른
    /// activityType 전환을 거부하기 때문이다 (아키텍처 2절 · D-M8).
    /// 세션은 근력 하나로 유지되고, 구간은 앱이 소유한다.
    @Published private(set) var mode: SegmentKind = .strength

    /// 세션 단계. 요약이 낄 자리를 만들려고 `isActive` 불리언을 대체했다.
    @Published private(set) var phase: SessionPhase = .idle
    /// 요약 화면이 읽고, 저장이 그대로 보내는 페이로드.
    @Published private(set) var pendingRecord: WorkoutRecordMessage?

    let session: WorkoutSessionService
    private let connectivity: WorkoutRecordSending
    private let remover: WorkoutRemoving
    private let defaults: UserDefaults
    private let snapshots: WorkoutSnapshotPublishing

    /// `isPaused` 구독을 붙잡아 둔다. 놓으면 정지/재개가 컴플리케이션에 안 나간다.
    private var cancellables: Set<AnyCancellable> = []

    /// W0 에서 고른 시작 유형. 세션 사이에 남는다.
    private static let startKindKey = "startSegmentKind"

    /// 구간 경계를 재는 쪽. **벽시계를 쓴다** — `session.elapsedSeconds` 는 손목을 내리면
    /// 멈추는 틱 카운터라 실기기에서 구간이 몇 초로 잡혔다 (`SegmentTracker` 주석).
    /// 세션 시작 시각도 여기가 단일 소스다.
    private var segments = SegmentTracker()

    init(session: WorkoutSessionService = WorkoutSessionService(configuration: .strength),
         connectivity: WorkoutRecordSending,
         remover: WorkoutRemoving = HealthKitWorkoutRemover(),
         defaults: UserDefaults = .standard,
         snapshots: WorkoutSnapshotPublishing = WorkoutSnapshotPublisher())
    {
        self.session = session
        self.connectivity = connectivity
        self.remover = remover
        self.defaults = defaults
        self.snapshots = snapshots

        // 저장된 값이 없거나 알아볼 수 없으면 근력으로 연다.
        mode = SegmentKind(rawValue: defaults.string(forKey: Self.startKindKey) ?? "") ?? .strength

        // 서비스의 개별 @Published 값을 뷰가 쓸 형태로 모아 다시 발행한다.
        // 감싸기만 하면 뷰가 갱신되지 않는다 — 서비스와 이 뷰모델은 서로 다른
        // ObservableObject 라 서비스의 변경이 이쪽 objectWillChange 로 이어지지 않는다.
        session.$isPaused
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPaused)

        // 정지/재개는 **여기서만** 컴플리케이션으로 나간다. `togglePause()` 에서 보내면
        // 세션이 실제로 멈췄는지 모르는 채 값을 지어내는 꼴이라(낙관적 토글 — 루트 `CLAUDE.md`
        // 워크아웃 계약), 서비스가 실제로 바꾼 값만 흘려보낸다.
        session.$isPaused
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] paused in
                MainActor.assumeIsolated {
                    guard let self, self.phase == .active else { return }
                    self.publishSnapshot(isPaused: paused)
                }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest4(
            session.$elapsedSeconds,
            session.$currentCalories,
            session.$currentBasalCalories,
            session.$currentHeartRate
        )
        .receive(on: DispatchQueue.main)
        .map { [session] _, _, _, _ in Self.snapshot(of: session) }
        .assign(to: &$metrics)
    }

    func requestAuthorization() async -> Bool {
        await session.requestAuthorization()
    }

    func start() {
        session.startWorkout()
        phase = .active
        WKInterfaceDevice.current().play(.start)
        // mode 는 W0 에서 고른 값 그대로다 — 첫 구간이 그 유형으로 열린다.
        // 세션 자체는 유형과 무관하게 실내 근력이다 (D-M8).
        segments.reset()
        publishSnapshot(isPaused: false)
    }

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

    /// 구간을 바꾼다. 열려 있던 구간을 닫고 새 구간을 연다.
    ///
    /// **햅틱이 필수다.** watchOS 커스텀 버튼은 햅틱이 자동으로 나지 않는데, 운동 중에는
    /// 화면을 계속 볼 수 없어 촉각이 유일한 확인 수단이다 (제품 스펙 5절).
    func switchMode(to newMode: SegmentKind) {
        guard newMode != mode else { return }
        segments.closeOpenSegment(kind: mode)
        mode = newMode
        // 눈 없이 방향을 구분할 수 있도록 상행·하행을 대칭으로 쓴다.
        WKInterfaceDevice.current().play(newMode == .cardio ? .directionUp : .directionDown)
        publishSnapshot(isPaused: isPaused)
    }

    /// 컴플리케이션이 읽을 상태를 내보낸다.
    ///
    /// **경과시간은 세션에서 가져온다** — 워치가 단일 소스라는 계약(루트 `CLAUDE.md`)을 여기서도
    /// 지킨다. `capturedAt` 과 짝으로 실어야 컴플리케이션이 타이머 기준점을 잡을 수 있다.
    private func publishSnapshot(isPaused: Bool) {
        snapshots.publish(WorkoutSnapshot(startedAt: segments.startedAt,
                                          mode: mode,
                                          isPaused: isPaused,
                                          elapsedSeconds: session.elapsedSeconds,
                                          capturedAt: Date()))
    }

    /// pause 는 워치가 소유한다. 폰에서 오는 명령은 후속 플랜에서 붙인다.
    func togglePause() {
        if session.isPaused {
            session.resumeWorkout()
        } else {
            session.pauseWorkout()
        }
        WKInterfaceDevice.current().play(.click)
    }

    /// 세션을 끝내고 기록을 폰으로 보낸다.
    ///
    /// **저장은 폰이 한다** — 워치 타깃은 `PersistenceCore` 를 링크하지 않는다 (아키텍처 7절).
    /// `.reliable` 이라 폰이 꺼져 있어도 `transferUserInfo` 가 큐잉하므로 기록이 유실되지 않는다.
    @discardableResult
    func end() async -> WorkoutResult? {
        // stopWorkout() 보다 먼저 닫는다. 그쪽이 총 시간을 재는 시점과 가장 가까워야
        // 구간 합계와 총 시간이 어긋나지 않는다 — HealthKit 마무리에 시간이 걸린다.
        segments.closeOpenSegment(kind: mode)

        let result = await session.stopWorkout()
        WKInterfaceDevice.current().play(.stop)
        // 세션이 끝났으니 컴플리케이션은 평상시 표시로 돌아간다. 저장/버리기와 무관하다.
        snapshots.clear()

        enterSummary(with: result.map(record(from:)))
        return result
    }

    private func record(from result: WorkoutResult) -> WorkoutRecordMessage {
        WorkoutRecordMessage(healthKitUUID: result.healthKitUUID,
                             startedAt: segments.startedAt,
                             endedAt: Date(),
                             totalSeconds: result.durationSeconds,
                             activeCalories: result.caloriesBurned,
                             totalCalories: result.totalCaloriesBurned,
                             averageHeartRate: result.averageHeartRate,
                             segments: segments.closed)
    }

    /// 총 칼로리는 활동 + 휴식이다 (YJKit README).
    private static func snapshot(of session: WorkoutSessionService) -> WorkoutMetrics {
        WorkoutMetrics(elapsedSeconds: TimeInterval(session.elapsedSeconds),
                       activeCalories: session.currentCalories,
                       totalCalories: session.currentCalories + session.currentBasalCalories,
                       heartRate: session.currentHeartRate)
    }

    // MARK: - 종료 후 결정 (W2)

    /// 종료 결과를 요약 화면이 읽을 형태로 보관한다. **아직 보내지 않는다** —
    /// 저장할지 버릴지는 사용자가 정한다.
    ///
    /// 결과가 없으면 세션이 애초에 없었다는 뜻이라 보여줄 것도 저장할 것도 없다.
    func enterSummary(with record: WorkoutRecordMessage?) {
        guard let record else {
            phase = .idle
            return
        }
        pendingRecord = record
        phase = .summary
    }

    /// 보관 중인 기록을 폰으로 보낸다.
    ///
    /// **저장은 폰이 한다** — 워치 타깃은 `PersistenceCore` 를 링크하지 않는다 (아키텍처 7절).
    func save() {
        guard let record = pendingRecord else { return }
        connectivity.sendReliably(record)
        pendingRecord = nil
        phase = .idle
        WKInterfaceDevice.current().play(.success)
    }

    /// 기록을 버린다. 폰으로 보내지 않고, **HealthKit 에 이미 저장된 워크아웃도 지운다** —
    /// 사용자가 버린 기록이 건강 앱에 남으면 명백한 배신이다 (제품 스펙 W2).
    func discard() {
        let uuid = pendingRecord?.healthKitUUID
        pendingRecord = nil
        phase = .idle
        WKInterfaceDevice.current().play(.failure)

        guard let uuid else { return }
        Task { await remover.remove(workoutWith: uuid) }
    }
}
