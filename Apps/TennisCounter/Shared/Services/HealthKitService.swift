import Foundation
import HealthKit

struct WorkoutResult {
    let durationSeconds: Int
    let caloriesBurned: Double
    let averageHeartRate: Double?
}

final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    @Published var isWorkoutActive = false
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

    private let typesToShare: Set<HKSampleType> = [
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate),
        HKObjectType.workoutType()
    ]
    private let typesToRead: Set<HKObjectType> = [
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.heartRate),
        HKObjectType.workoutType()
    ]

    private init() {}

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

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
        guard isAvailable else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .tennis
        config.locationType = .outdoor

        do {
            let session = try HKWorkoutSession(healthStore: store, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: config)

            workoutSession = session
            liveWorkoutBuilder = builder

            session.startActivity(with: Date())
            builder.beginCollection(withStart: Date()) { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.isWorkoutActive = true
                    self?.startDate = Date()
                    self?.startTimer()
                }
            }
        } catch {}
    }

    func stopWorkout() async -> WorkoutResult? {
        guard let session = workoutSession,
              let builder = liveWorkoutBuilder,
              let start = startDate else { return nil }

        session.end()
        stopTimer()

        let elapsed = Int(Date().timeIntervalSince(start))
        let calories = await collectCalories(builder: builder)
        let heartRate = await collectAverageHeartRate(builder: builder)

        await withCheckedContinuation { continuation in
            builder.endCollection(withEnd: Date()) { _, _ in continuation.resume() }
        }
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

    private func startTimer() {
        elapsedSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func formattedElapsed() -> String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
