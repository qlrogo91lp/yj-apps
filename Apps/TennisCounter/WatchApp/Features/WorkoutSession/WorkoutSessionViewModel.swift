import Combine
import Foundation

@MainActor
class WorkoutSessionViewModel: ObservableObject {
    @Published var phase: MatchPhase = .modeSelection
    @Published var isPaused: Bool = false

    let healthKit = HealthKitService.shared
    let workoutSessionId: UUID = .init()

    private var cancellables = Set<AnyCancellable>()

    init() {
        healthKit.$isPaused
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPaused)
    }

    func startWorkout() {
        healthKit.startWorkout()
    }

    func startMatch(options: MatchOptions) {
        let session = MatchSession(
            workoutSessionId: workoutSessionId,
            options: options,
            kcalAtStart: healthKit.currentCalories
        )
        phase = .playing(options)
        // Store session reference for finishMatch
        _currentSession = session
    }

    private var _currentSession: MatchSession?

    func currentSession() -> MatchSession? {
        _currentSession
    }

    func finishMatch(result: MatchResult, completedSets: [SetScore]) {
        guard let session = _currentSession else { return }
        session.endedAt = Date()
        session.result = result
        session.completedSets = completedSets
        session.kcalAtEnd = healthKit.currentCalories
        session.mySetScore = completedSets.count(where: { $0.my > $0.your })
        session.yourSetScore = completedSets.count(where: { $0.your > $0.my })

        phase = .finished(session)

        Task {
            session.averageHeartRate = await healthKit.averageHeartRate(
                from: session.startedAt,
                to: session.endedAt ?? Date()
            )
        }
    }

    func saveCurrentMatch() throws {
        guard let session = _currentSession else { return }
        let record = MatchRecord(from: session)
        try MatchPersistenceService.shared.save(record)
    }

    func startNewMatch() {
        _currentSession = nil
        phase = .modeSelection
    }

    func restartMatch() {
        guard let options = _currentSession?.options else { return }
        startMatch(options: options)
    }

    func pauseWorkout() {
        healthKit.pauseWorkout()
    }

    func resumeWorkout() {
        healthKit.resumeWorkout()
    }

    func endWorkout() {
        _currentSession = nil
        Task { _ = await healthKit.stopWorkout() }
    }
}
