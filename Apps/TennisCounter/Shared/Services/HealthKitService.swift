import Foundation
import HealthKit

struct WorkoutResult {
    let durationSeconds: Int
    let caloriesBurned: Double
    let averageHeartRate: Double?
}

final class HealthKitService: NSObject, ObservableObject {
    static let shared = HealthKitService()

    @Published var isWorkoutActive = false
    @Published var isPaused: Bool = false
    @Published var currentHeartRate: Double = 0
    @Published var currentCalories: Double = 0
    @Published var elapsedSeconds: Int = 0

    private let store = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKWorkoutBuilder?
    #if os(watchOS)
        private var liveWorkoutBuilder: HKLiveWorkoutBuilder?
    #endif
    private var startDate: Date?
    private var timer: Timer?
    private var timerPausedAt: Date?

    private let typesToShare: Set<HKSampleType> = [
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate),
        HKObjectType.workoutType(),
    ]
    private let typesToRead: Set<HKObjectType> = [
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate),
        HKObjectType.workoutType(),
    ]

    override private init() {}

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: typesToShare, read: typesToRead)
            return true
        } catch {
            return false
        }
    }

    #if os(watchOS)
        func startWorkout() {
            guard isAvailable, workoutSession == nil else { return }

            let config = HKWorkoutConfiguration()
            config.activityType = .tennis
            config.locationType = .outdoor

            do {
                let session = try HKWorkoutSession(healthStore: store, configuration: config)
                let builder = session.associatedWorkoutBuilder()
                builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)

                session.delegate = self
                builder.delegate = self

                workoutSession = session
                liveWorkoutBuilder = builder

                let now = Date()
                startDate = now
                startTimer()

                session.startActivity(with: now)
                builder.beginCollection(withStart: now) { [weak self] _, _ in
                    DispatchQueue.main.async {
                        self?.isWorkoutActive = true
                    }
                }
            } catch {}
        }

        func pauseWorkout() {
            guard let session = workoutSession else { return }
            session.pause()
            DispatchQueue.main.async { self.isPaused = true }
            timerPausedAt = Date()
            timer?.invalidate()
            timer = nil
        }

        func resumeWorkout() {
            guard let session = workoutSession else { return }
            session.resume()
            DispatchQueue.main.async { self.isPaused = false }
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.elapsedSeconds += 1
                }
            }
            timerPausedAt = nil
        }

        func stopWorkout() async -> WorkoutResult? {
            guard let session = workoutSession,
                  let builder = liveWorkoutBuilder,
                  let start = startDate else { return nil }

            workoutSession = nil
            liveWorkoutBuilder = nil
            startDate = nil

            session.end()
            stopTimer()

            let elapsed = Int(Date().timeIntervalSince(start))
            let endDate = Date()

            await withCheckedContinuation { continuation in
                builder.endCollection(withEnd: endDate) { _, _ in continuation.resume() }
            }

            let calories = await collectCalories(builder: builder)
            let heartRate = await collectAverageHeartRate(builder: builder)

            try? await builder.finishWorkout()

            DispatchQueue.main.async { self.isWorkoutActive = false }
            return WorkoutResult(durationSeconds: elapsed, caloriesBurned: calories, averageHeartRate: heartRate)
        }

        private func collectCalories(builder: HKLiveWorkoutBuilder) async -> Double {
            builder.statistics(for: HKQuantityType(.activeEnergyBurned))?
                .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        }

        private func collectAverageHeartRate(builder: HKLiveWorkoutBuilder) async -> Double? {
            builder.statistics(for: HKQuantityType(.heartRate))?
                .averageQuantity()?.doubleValue(for: HKUnit(from: "count/min"))
        }
    #endif

    func averageHeartRate(from startDate: Date, to endDate: Date) async -> Double? {
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

    func formattedElapsed() -> String {
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
    extension HealthKitService: HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
        func workoutSession(_: HKWorkoutSession,
                            didChangeTo toState: HKWorkoutSessionState,
                            from _: HKWorkoutSessionState,
                            date _: Date)
        {
            DispatchQueue.main.async {
                self.isWorkoutActive = toState == .running
                self.isPaused = toState == .paused
            }
        }

        func workoutSession(_: HKWorkoutSession, didFailWithError _: Error) {}

        func workoutBuilderDidCollectEvent(_: HKLiveWorkoutBuilder) {}

        func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf _: Set<HKSampleType>) {
            DispatchQueue.main.async {
                if let stats = workoutBuilder.statistics(for: HKQuantityType(.heartRate)) {
                    self.currentHeartRate = stats.mostRecentQuantity()?.doubleValue(for: HKUnit(from: "count/min")) ?? self.currentHeartRate
                }
                if let stats = workoutBuilder.statistics(for: HKQuantityType(.activeEnergyBurned)) {
                    self.currentCalories = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? self.currentCalories
                }
            }
        }
    }
#endif
