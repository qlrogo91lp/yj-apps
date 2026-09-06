import Combine
import Foundation
import WatchKit
import WorkoutCore

/// 세션 안의 현재 운동 구간. **HealthKit 은 이 전환을 모른다** — 근력↔유산소처럼
/// 카테고리가 다른 activityType 전환을 거부하기 때문이다 (아키텍처 2절 · D-M8).
/// 세션은 근력 하나로 유지되고, 구간은 앱이 소유한다.
enum WorkoutMode: Int, CaseIterable {
    case strength
    case cardio

    var title: String {
        switch self {
        case .strength: "근력"
        case .cardio: "유산소"
        }
    }
}

/// 워치 워크아웃 세션의 소유자.
/// `WorkoutSessionService` 는 싱글톤이 아니므로 앱 루트에서 한 번 만들어 주입한다 (YJKit README).
@MainActor
final class WorkoutViewModel: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var isPaused = false
    @Published private(set) var metrics = WorkoutMetrics()
    @Published private(set) var mode: WorkoutMode = .strength

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
        mode = .strength
    }

    /// 구간을 바꾼다. 저장은 아직 하지 않는다 — 전환 시각을 SwiftData 세그먼트로 남기는 것은
    /// 데이터 모델이 생긴 뒤의 별도 플랜이다. 지금은 화면 표시만 바뀐다.
    ///
    /// **햅틱이 필수다.** watchOS 커스텀 버튼은 햅틱이 자동으로 나지 않는데, 운동 중에는
    /// 화면을 계속 볼 수 없어 촉각이 유일한 확인 수단이다 (제품 스펙 5절).
    func switchMode(to newMode: WorkoutMode) {
        guard newMode != mode else { return }
        mode = newMode
        // 눈 없이 방향을 구분할 수 있도록 상행·하행을 대칭으로 쓴다.
        WKInterfaceDevice.current().play(newMode == .cardio ? .directionUp : .directionDown)
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
