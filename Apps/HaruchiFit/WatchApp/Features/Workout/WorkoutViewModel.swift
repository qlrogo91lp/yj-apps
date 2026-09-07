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

    /// 닫힌 구간들. 열려 있는 마지막 구간은 `openSegmentStart` 로만 들고 있다가 종료 시 닫는다.
    private var closedSegments: [WorkoutRecordMessage.SegmentPayload] = []
    /// 현재 구간이 시작된 오프셋(초). 경과시간은 워치가 단일 소스라 여기서도 그 값을 쓴다.
    private var openSegmentStart = 0
    private var startedAt = Date()

    init(session: WorkoutSessionService = WorkoutSessionService(configuration: .strength),
         connectivity: WorkoutRecordSending,
         remover: WorkoutRemoving = HealthKitWorkoutRemover())
    {
        self.session = session
        self.connectivity = connectivity
        self.remover = remover

        // 서비스의 개별 @Published 값을 뷰가 쓸 형태로 모아 다시 발행한다.
        // 감싸기만 하면 뷰가 갱신되지 않는다 — 서비스와 이 뷰모델은 서로 다른
        // ObservableObject 라 서비스의 변경이 이쪽 objectWillChange 로 이어지지 않는다.
        session.$isPaused
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPaused)

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
        mode = .strength
        closedSegments = []
        openSegmentStart = 0
        startedAt = Date()
    }

    /// 구간을 바꾼다. 열려 있던 구간을 닫고 새 구간을 연다.
    ///
    /// **햅틱이 필수다.** watchOS 커스텀 버튼은 햅틱이 자동으로 나지 않는데, 운동 중에는
    /// 화면을 계속 볼 수 없어 촉각이 유일한 확인 수단이다 (제품 스펙 5절).
    func switchMode(to newMode: SegmentKind) {
        guard newMode != mode else { return }
        closeOpenSegment(at: session.elapsedSeconds)
        mode = newMode
        // 눈 없이 방향을 구분할 수 있도록 상행·하행을 대칭으로 쓴다.
        WKInterfaceDevice.current().play(newMode == .cardio ? .directionUp : .directionDown)
    }

    /// 열린 구간을 닫아 `closedSegments` 에 넣는다. 길이가 0이면 버린다 —
    /// 전환을 연달아 눌렀을 때 빈 구간이 쌓이는 것을 막는다.
    private func closeOpenSegment(at elapsed: Int) {
        let duration = elapsed - openSegmentStart
        if duration > 0 {
            closedSegments.append(.init(kind: mode,
                                        startOffset: openSegmentStart,
                                        durationSeconds: duration))
        }
        openSegmentStart = elapsed
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
        // 마지막 구간은 stopWorkout() 이 타이머를 멈추기 전의 경과시간으로 닫는다.
        closeOpenSegment(at: session.elapsedSeconds)

        let result = await session.stopWorkout()
        WKInterfaceDevice.current().play(.stop)

        enterSummary(with: result.map(record(from:)))
        return result
    }

    private func record(from result: WorkoutResult) -> WorkoutRecordMessage {
        WorkoutRecordMessage(healthKitUUID: result.healthKitUUID,
                             startedAt: startedAt,
                             endedAt: Date(),
                             totalSeconds: result.durationSeconds,
                             activeCalories: result.caloriesBurned,
                             totalCalories: result.totalCaloriesBurned,
                             averageHeartRate: result.averageHeartRate,
                             segments: closedSegments)
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
