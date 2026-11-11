import Foundation
import HealthKit

public final class WorkoutSessionService: NSObject, ObservableObject {
    @Published public private(set) var isWorkoutActive = false
    @Published public private(set) var isPaused: Bool = false
    @Published public private(set) var currentHeartRate: Double = 0
    @Published public private(set) var currentCalories: Double = 0
    @Published public private(set) var currentBasalCalories: Double = 0
    @Published public private(set) var elapsedSeconds: Int = 0
    @Published public private(set) var currentDistanceMeters: Double = 0
    @Published public private(set) var currentSteps: Int = 0
    /// 정지 제외 기준시각 모델. 운동이 시작되기 전이나 시작에 실패하면 nil.
    /// 기존 `elapsedSeconds`(틱 카운터)는 그대로 유지한다 — 저장·전송 의미는 이 값에 의존하지 않는다.
    @Published public private(set) var elapsedDisplay: WorkoutElapsedDisplay?

    /// 운동 생애주기(시작·종료)마다 바뀌는 세대 토큰. 지연 도착한 delegate 콜백이 이미 끝났거나
    /// 다음 운동이 시작된 뒤의 표시 모델을 덮어쓰지 않도록, 호출 시점에 캡처한 세대와 비교한다.
    private var elapsedDisplayGeneration = 0

    public let configuration: WorkoutConfiguration

    private let store = HKHealthStore()
    #if os(watchOS)
        private var workoutSession: HKWorkoutSession?
        private var liveWorkoutBuilder: HKLiveWorkoutBuilder?
        /// `stopWorkout()` 이 세션의 `.stopped` 전환을 기다리는 동안만 있다. delegate 가 푼다.
        private var stopWaiter: StopWaiter?
    #endif
    public private(set) var startDate: Date?
    private var timer: Timer?

    /// 쓰기는 운동 하나뿐이다. 심박·칼로리는 읽기 권한만으로 수집·저장됨을
    /// 2026-10-11 시뮬레이터와 실기기에서 확인했다 (HealthKit 권한 시트 정리 플랜).
    var typesToShare: Set<HKSampleType> {
        [HKObjectType.workoutType()]
    }

    /// 기본 3종 + configuration이 지정한 추가 타입. 워치는 과거 운동을 조회하지 않는다.
    var typesToRead: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.heartRate),
        ]
        for identifier in configuration.additionalReadTypes {
            types.insert(HKQuantityType(identifier))
        }
        return types
    }

    public init(configuration: WorkoutConfiguration) {
        self.configuration = configuration
        super.init()
    }

    /// 타이머 클로저가 [weak self]라 순환 참조는 없지만, 서비스가 해제되면
    /// 런루프에 남은 타이머가 빈 틱을 계속 돌린다 — 해제 시점에 정리한다.
    deinit {
        timer?.invalidate()
    }

    public var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    public func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
            return true
        } catch {
            return false
        }
    }

    #if os(watchOS)
        public func startWorkout() {
            guard isAvailable, workoutSession == nil else { return }

            let config = HKWorkoutConfiguration()
            config.activityType = configuration.activityType
            config.locationType = configuration.locationType

            do {
                let session = try HKWorkoutSession(healthStore: store, configuration: config)
                let builder = session.associatedWorkoutBuilder()
                let dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)
                for identifier in configuration.additionalReadTypes {
                    dataSource.enableCollection(for: HKQuantityType(identifier), predicate: nil)
                }
                builder.dataSource = dataSource

                session.delegate = self
                builder.delegate = self

                workoutSession = session
                liveWorkoutBuilder = builder

                let now = Date()
                startDate = now
                currentDistanceMeters = 0
                currentSteps = 0
                startTimer()
                beginElapsedDisplaySession(at: now)

                session.startActivity(with: now)
                builder.beginCollection(withStart: now) { [weak self] _, _ in
                    DispatchQueue.main.async {
                        self?.isWorkoutActive = true
                    }
                }
            } catch {}
        }

        public func pauseWorkout() {
            guard let session = workoutSession else { return }
            session.pause()
            let now = Date()
            let generation = elapsedDisplayGeneration
            DispatchQueue.main.async {
                self.isPaused = true
                self.applyElapsedDisplayState(.paused, at: now, generation: generation)
            }
            timer?.invalidate()
            timer = nil
        }

        public func resumeWorkout() {
            guard let session = workoutSession else { return }
            session.resume()
            let now = Date()
            let generation = elapsedDisplayGeneration
            DispatchQueue.main.async {
                self.isPaused = false
                self.applyElapsedDisplayState(.running, at: now, generation: generation)
            }
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.elapsedSeconds += 1
                }
            }
        }

        public func stopWorkout() async -> WorkoutResult? {
            guard let session = workoutSession,
                  let builder = liveWorkoutBuilder,
                  let start = startDate else { return nil }

            workoutSession = nil
            liveWorkoutBuilder = nil
            startDate = nil

            let endDate = Date()
            stopTimer()
            endElapsedDisplaySession(at: endDate)

            // 세션을 끝내기(end) 전에 활동만 멈춘다. `.stopped` 동안은 앱이 백그라운드 실행 권한을 유지해
            // 손목을 내려도 아래 마무리(특히 finishWorkout — 건강 앱 운동 저장)가 멈추지 않는다.
            // end() 를 먼저 부르면 권한을 잃어 마무리가 다음 활성화까지 밀리거나 사라졌다 (10-21 Ralli 저장 지연).
            await stopActivity(of: session, at: endDate)

            let elapsed = Int(endDate.timeIntervalSince(start))

            await withCheckedContinuation { continuation in
                builder.endCollection(withEnd: endDate) { _, _ in continuation.resume() }
            }

            let calories = await collectCalories(builder: builder)
            let basal = await collectBasalCalories(builder: builder)
            let heartRate = await collectAverageHeartRate(builder: builder)
            let distance = await collectDistance(builder: builder)
            let steps = await collectSteps(builder: builder)

            // finishWorkout()이 방금 저장된 HKWorkout을 돌려준다. 앱이 자기 저장소의 기록과
            // 잇는 매칭 키로 쓰므로 버리지 않는다. 저장 실패 시엔 nil이 되고 앱은 시간으로 맞춘다.
            let saved = try? await builder.finishWorkout()
            session.end()

            DispatchQueue.main.async { self.isWorkoutActive = false }
            return WorkoutResult(durationSeconds: elapsed,
                                 caloriesBurned: calories,
                                 averageHeartRate: heartRate,
                                 totalCaloriesBurned: calories + basal,
                                 distanceMeters: distance,
                                 steps: steps,
                                 healthKitUUID: saved?.uuid,
                                 endedAt: endDate)
        }

        /// `stopActivity` 뒤 `.stopped` 전환을 기다린다 (Apple 워크아웃 미러링 샘플의 종료 순서).
        /// 전환이 오지 않는 경우에 대비해 3초 뒤엔 그냥 진행한다.
        private func stopActivity(of session: HKWorkoutSession, at date: Date) async {
            guard session.state != .stopped else { return }
            let waiter = StopWaiter()
            stopWaiter = waiter
            await waiter.wait(timeout: 3) { session.stopActivity(with: date) }
            stopWaiter = nil
        }

        private func collectCalories(builder: HKLiveWorkoutBuilder) async -> Double {
            builder.statistics(for: HKQuantityType(.activeEnergyBurned))?
                .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        }

        private func collectDistance(builder: HKLiveWorkoutBuilder) async -> Double {
            builder.statistics(for: HKQuantityType(.distanceWalkingRunning))?
                .sumQuantity()?.doubleValue(for: .meter()) ?? 0
        }

        private func collectSteps(builder: HKLiveWorkoutBuilder) async -> Int {
            let value = builder.statistics(for: HKQuantityType(.stepCount))?
                .sumQuantity()?.doubleValue(for: .count())
            return value.map { Int($0) } ?? 0
        }

        private func collectBasalCalories(builder: HKLiveWorkoutBuilder) async -> Double {
            builder.statistics(for: HKQuantityType(.basalEnergyBurned))?
                .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        }

        private func collectAverageHeartRate(builder: HKLiveWorkoutBuilder) async -> Double? {
            builder.statistics(for: HKQuantityType(.heartRate))?
                .averageQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
        }
    #endif

    public func averageHeartRate(from startDate: Date, to endDate: Date) async -> Double? {
        #if os(watchOS)
            let hrType = HKQuantityType(.heartRate)
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
            return await withCheckedContinuation { continuation in
                let query = HKStatisticsQuery(
                    quantityType: hrType,
                    quantitySamplePredicate: predicate,
                    options: .discreteAverage
                ) { _, stats, _ in
                    let value = stats?.averageQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
                    continuation.resume(returning: value)
                }
                store.execute(query)
            }
        #else
            return nil
        #endif
    }

    private func startTimer() {
        elapsedSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.elapsedSeconds += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    /// 현재 세대 토큰. 호출 시점(delegate 콜백이 실제로 불린 시점)에 캡처해 `applyElapsedDisplayState`에
    /// 넘기면, 그 세대가 끝난 뒤 지연 도착해도 `generation` 비교로 걸러진다.
    internal var currentElapsedDisplayGeneration: Int {
        elapsedDisplayGeneration
    }

    /// 새 운동의 표시 기준을 만든다. `startWorkout()`의 성공 경로에서 `startDate`와 같은 지점에 부른다.
    internal func beginElapsedDisplaySession(at date: Date) {
        elapsedDisplayGeneration += 1
        elapsedDisplay = WorkoutElapsedDisplay(referenceDate: date)
    }

    /// 표시를 종료 요청 시각에 고정한다. `stopWorkout()`의 HealthKit 마무리를 기다리는 동안
    /// 표시가 더 흐르지 않게, 그리고 이후 지연 도착한 이벤트가 덮어쓰지 못하게 세대도 함께 올린다.
    internal func endElapsedDisplaySession(at date: Date) {
        elapsedDisplay = elapsedDisplay?.pausing(at: date)
        elapsedDisplayGeneration += 1
    }

    /// HK 세션 상태 변화를 표시 모델에 반영한다. `generation`이 현재 세대와 다르면(이미 끝났거나
    /// 다음 운동이 시작된 뒤 지연 도착한 이벤트) 무시한다.
    internal func applyElapsedDisplayState(_ state: HKWorkoutSessionState, at date: Date, generation: Int) {
        guard generation == elapsedDisplayGeneration else { return }
        switch state {
        case .running:
            elapsedDisplay = elapsedDisplay?.resuming(at: date)
        case .paused:
            elapsedDisplay = elapsedDisplay?.pausing(at: date)
        default:
            break
        }
    }

    public func formattedElapsed() -> String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#if os(watchOS)
    extension WorkoutSessionService: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
        public func workoutSession(_: HKWorkoutSession,
                                   didChangeTo toState: HKWorkoutSessionState,
                                   from _: HKWorkoutSessionState,
                                   date: Date)
        {
            if toState == .stopped { stopWaiter?.resume() }
            // 호출 시점(이 delegate가 실제로 불린 시점)에 세대를 캡처한다 — dispatch된 블록 안에서
            // 읽으면 그 사이 다음 운동이 시작돼 세대가 이미 바뀐 뒤일 수 있어, 지연 도착 판별이 무의미해진다.
            let generation = elapsedDisplayGeneration
            DispatchQueue.main.async {
                self.isWorkoutActive = toState == .running
                self.isPaused = toState == .paused
                self.applyElapsedDisplayState(toState, at: date, generation: generation)
            }
        }

        public func workoutSession(_: HKWorkoutSession, didFailWithError _: Error) {}

        public func workoutBuilderDidCollectEvent(_: HKLiveWorkoutBuilder) {}

        public func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf _: Set<HKSampleType>) {
            DispatchQueue.main.async {
                if let stats = workoutBuilder.statistics(for: HKQuantityType(.heartRate)) {
                    self.currentHeartRate = stats.mostRecentQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? self.currentHeartRate
                }
                if let stats = workoutBuilder.statistics(for: HKQuantityType(.activeEnergyBurned)) {
                    self.currentCalories = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? self.currentCalories
                }
                if let stats = workoutBuilder.statistics(for: HKQuantityType(.basalEnergyBurned)) {
                    self.currentBasalCalories = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? self.currentBasalCalories
                }
                if let stats = workoutBuilder.statistics(for: HKQuantityType(.distanceWalkingRunning)) {
                    self.currentDistanceMeters = stats.sumQuantity()?.doubleValue(for: .meter()) ?? self.currentDistanceMeters
                }
                if let stats = workoutBuilder.statistics(for: HKQuantityType(.stepCount)) {
                    let value = stats.sumQuantity()?.doubleValue(for: .count())
                    self.currentSteps = value.map { Int($0) } ?? self.currentSteps
                }
            }
        }
    }
#endif

#if os(watchOS)
    /// `.stopped` 전환과 타임아웃 중 먼저 온 쪽이 continuation 을 한 번만 푼다.
    /// delegate 는 임의의 큐에서 불리므로 잠금으로 지킨다.
    private final class StopWaiter: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Void, Never>?

        func wait(timeout seconds: Double, starting start: () -> Void) async {
            await withCheckedContinuation { continuation in
                lock.lock()
                self.continuation = continuation
                lock.unlock()
                start()
                DispatchQueue.global().asyncAfter(deadline: .now() + seconds) { self.resume() }
            }
        }

        func resume() {
            lock.lock()
            let continuation = continuation
            self.continuation = nil
            lock.unlock()
            continuation?.resume()
        }
    }
#endif

#if DEBUG
    public extension WorkoutSessionService {
        /// 테스트·프리뷰 전용: HealthKit 세션 없이 표시 값을 주입한다. 릴리즈 빌드에는 포함되지 않는다.
        func setLiveMetricsForTesting(heartRate: Double? = nil,
                                      calories: Double? = nil,
                                      basalCalories: Double? = nil,
                                      elapsedSeconds: Int? = nil,
                                      distanceMeters: Double? = nil,
                                      steps: Int? = nil)
        {
            if let heartRate { currentHeartRate = heartRate }
            if let calories { currentCalories = calories }
            if let basalCalories { currentBasalCalories = basalCalories }
            if let elapsedSeconds { self.elapsedSeconds = elapsedSeconds }
            if let distanceMeters { currentDistanceMeters = distanceMeters }
            if let steps { currentSteps = steps }
        }
    }
#endif
