import Combine
import Foundation
import WorkoutCore

/// 워치 워크아웃 세션의 소유자.
/// `WorkoutSessionService` 는 싱글톤이 아니므로 앱 루트에서 한 번 만들어 주입한다 (YJKit README).
@MainActor
final class WorkoutViewModel: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var isPaused = false
    @Published private(set) var metrics = WorkoutMetrics()

    let session: WorkoutSessionService

    init(session: WorkoutSessionService = WorkoutSessionService(configuration: .strength)) {
        self.session = session

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
        isActive = true
    }

    /// pause 는 워치가 소유한다. 폰에서 오는 명령은 후속 플랜에서 붙인다.
    func togglePause() {
        if session.isPaused {
            session.resumeWorkout()
        } else {
            session.pauseWorkout()
        }
    }

    @discardableResult
    func end() async -> WorkoutResult? {
        let result = await session.stopWorkout()
        isActive = false
        return result
    }

    /// 총 칼로리는 활동 + 휴식이다 (YJKit README).
    private static func snapshot(of session: WorkoutSessionService) -> WorkoutMetrics {
        WorkoutMetrics(elapsedSeconds: TimeInterval(session.elapsedSeconds),
                       activeCalories: session.currentCalories,
                       totalCalories: session.currentCalories + session.currentBasalCalories,
                       heartRate: session.currentHeartRate)
    }
}
