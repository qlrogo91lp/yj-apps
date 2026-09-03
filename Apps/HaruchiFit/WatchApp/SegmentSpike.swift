import Combine
import Foundation
import HealthKit

/// 스파이크 전용 — `HKWorkoutActivity` 구간이 실제로 저장되는지 확인한다.
/// **검증이 끝나면 이 파일과 `SpikeView` 를 통째로 삭제한다.**
///
/// `WorkoutSessionService` 는 `HKWorkoutSession` 을 private 으로 감추고 있어 밖에서 구간을
/// 걸 수 없다. 패키지를 고치는 건 검증 결과가 나온 뒤이므로(아키텍처 2절) 여기서는 서비스를
/// 쓰지 않고 자기 세션을 직접 만든다. Task 5 의 코드는 건드리지 않는다.
@MainActor
final class SegmentSpike: NSObject, ObservableObject {
    @Published private(set) var log: [String] = []
    @Published private(set) var elapsed: Int = 0
    @Published private(set) var isRunning = false

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var timer: Timer?
    private var startDate: Date?

    // MARK: - 세션

    func start() {
        guard session == nil else {
            append("이미 세션이 돌고 있다")
            return
        }
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
            session.delegate = self

            let now = Date()
            session.startActivity(with: now)
            builder.beginCollection(withStart: now) { _, _ in }

            self.session = session
            self.builder = builder
            startDate = now
            isRunning = true
            startTimer()
            append("세션 시작 (근력 \(activityLabel(.traditionalStrengthTraining)))")
        } catch {
            append("세션 생성 실패: \(error)")
        }
    }

    /// 유산소 구간을 연다. `beginNewActivity` 는 비동기이며 실제 시작은 델리게이트가 알려준다.
    func beginCardio() {
        beginActivity(.running, label: "유산소")
    }

    /// 시나리오 B용 — `endCurrentActivity` 대신 근력 구간을 새로 열어 되돌아간다.
    func beginStrength() {
        beginActivity(.traditionalStrengthTraining, label: "근력")
    }

    /// 현재 구간을 닫는다. SDK 헤더에 따르면 **메인 세션 활동(근력)으로 되돌아간다.**
    func endCurrentActivity() {
        guard let session else {
            append("세션 없음")
            return
        }
        session.endCurrentActivity(on: Date())
        append("구간 종료 요청 → 메인(근력) 복귀 예상")
    }

    func end() async {
        guard let session, let builder else {
            append("세션 없음")
            return
        }
        stopTimer()
        let endDate = Date()
        session.end()
        await withCheckedContinuation { continuation in
            builder.endCollection(withEnd: endDate) { _, _ in continuation.resume() }
        }
        do {
            _ = try await builder.finishWorkout()
            append("세션 종료 — 전체 \(elapsed)초")
        } catch {
            append("finishWorkout 실패: \(error)")
        }
        self.session = nil
        self.builder = nil
        isRunning = false
        await inspectLastWorkout()
    }

    // MARK: - 되읽기

    /// 방금 저장된 워크아웃을 다시 읽어 구간이 남았는지 본다.
    func inspectLastWorkout() async {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let samples: [HKSample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(),
                                      predicate: nil,
                                      limit: 1,
                                      sortDescriptors: [sort])
            { _, samples, _ in
                continuation.resume(returning: samples ?? [])
            }
            store.execute(query)
        }

        guard let workout = samples.first as? HKWorkout else {
            append("워크아웃 없음")
            return
        }
        let activities = workout.workoutActivities
        append("전체 \(Int(workout.duration))초 · 구간 \(activities.count)개")
        for (index, activity) in activities.enumerated() {
            let type = activity.workoutConfiguration.activityType
            let end = activity.endDate.map(Self.time) ?? "진행중"
            append("  [\(index)] \(activityLabel(type)) \(Self.time(activity.startDate)) → \(end)")
        }
    }

    // MARK: - 내부

    private func beginActivity(_ type: HKWorkoutActivityType, label: String) {
        guard let session else {
            append("세션 없음 — 먼저 시작한다")
            return
        }
        let config = HKWorkoutConfiguration()
        config.activityType = type
        config.locationType = .indoor
        session.beginNewActivity(configuration: config, date: Date(), metadata: nil)
        append("\(label) 구간 요청 (\(activityLabel(type)))")
    }

    private func startTimer() {
        stopTimer()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            // Task 안에서 캡처된 var(self?)를 직접 쓰면 Swift 6 모드에서 에러다. 먼저 묶는다.
            guard let self else { return }
            Task { @MainActor in self.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard let startDate else { return }
        elapsed = Int(Date().timeIntervalSince(startDate))
    }

    /// 판정에 쓰는 raw value 를 이름과 함께 남긴다 — 근력 50, 달리기 37.
    private func activityLabel(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .traditionalStrengthTraining: "strength=\(type.rawValue)"
        case .running: "running=\(type.rawValue)"
        default: "type=\(type.rawValue)"
        }
    }

    private static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .standard)
    }

    private func append(_ line: String) {
        let stamped = "\(Self.time(Date())) \(line)"
        log.append(stamped)
        print("[SPIKE] \(stamped)")
    }
}

// MARK: - HKWorkoutSessionDelegate

extension SegmentSpike: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_: HKWorkoutSession,
                                    didChangeTo toState: HKWorkoutSessionState,
                                    from _: HKWorkoutSessionState,
                                    date _: Date)
    {
        Task { @MainActor in self.append("세션 상태 \(toState.rawValue)") }
    }

    nonisolated func workoutSession(_: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in self.append("세션 실패: \(error)") }
    }

    /// 구간이 **실제로** 시작된 시점. 요청과 이 콜백 사이의 지연이 검증 포인트다.
    nonisolated func workoutSession(_: HKWorkoutSession,
                                    didBeginActivityWith configuration: HKWorkoutConfiguration,
                                    date: Date)
    {
        let type = configuration.activityType
        Task { @MainActor in
            self.append("구간 시작됨: \(self.activityLabel(type)) at \(Self.time(date))")
        }
    }

    nonisolated func workoutSession(_: HKWorkoutSession,
                                    didEndActivityWith configuration: HKWorkoutConfiguration,
                                    date: Date)
    {
        let type = configuration.activityType
        Task { @MainActor in
            self.append("구간 종료됨: \(self.activityLabel(type)) at \(Self.time(date))")
        }
    }
}
