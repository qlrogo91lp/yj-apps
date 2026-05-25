import Combine
import Foundation
import WidgetKit

@MainActor
class WorkoutSessionViewModel: ObservableObject {
    @Published var phase: MatchPhase = .modeSelection
    @Published var isPaused: Bool = false
    @Published var remoteWorkoutEnded: Bool = false

    let healthKit = HealthKitService.shared
    let workoutSessionId: UUID = .init()
    @Published private(set) var lastMetrics: WorkoutMetrics?

    private let connectivity = WatchConnectivityService.shared
    private let appGroupDefaults = UserDefaults(suiteName: "group.com.yj.TennisCounter")
    private let metricsThrottle: TimeInterval
    private var cancellables = Set<AnyCancellable>()
    private var _currentSession: MatchSession?

    init(metricsThrottle: TimeInterval = 5) {
        self.metricsThrottle = metricsThrottle
        healthKit.$isPaused
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPaused)

        connectivity.$receivedSessionStart
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in
                guard let self, case .modeSelection = self.phase else { return }
                if !self.healthKit.isWorkoutActive { self.startWorkout() }
                self.startMatch(options: msg.options, sessionId: msg.sessionId, isRemote: true)
            }
            .store(in: &cancellables)

        connectivity.$receivedWorkoutEnd
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.endWorkout()
                self.remoteWorkoutEnded = true
            }
            .store(in: &cancellables)

        healthKit.$currentHeartRate
            .dropFirst()
            .throttle(for: .seconds(metricsThrottle), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                guard let self, case .playing = self.phase else { return }
                self.broadcastMetrics()
            }
            .store(in: &cancellables)
    }

    func startWorkout() {
        Task {
            await healthKit.requestAuthorization()
            healthKit.startWorkout()
            appGroupDefaults?.set(true, forKey: "isWorkoutActive")
            WidgetCenter.shared.reloadTimelines(ofKind: "ComplicationApp")
        }
    }

    func startMatch(options: MatchOptions, sessionId: UUID? = nil, isRemote: Bool = false) {
        let id = sessionId ?? workoutSessionId
        let session = MatchSession(
            workoutSessionId: id,
            options: options,
            kcalAtStart: healthKit.currentCalories
        )
        _currentSession = session
        phase = .playing(options)

        if !isRemote {
            connectivity.sendSessionStart(SessionStartMessage(sessionId: id, options: options))
        }
    }

    func currentSession() -> MatchSession? { _currentSession }

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
            sendMatchEndToiOS(session: session)
        }
    }

    func saveCurrentMatch() throws {
        guard let session = _currentSession else { return }
        let match = Match()
        match.workoutSessionId = session.workoutSessionId
        match.startedAt = session.startedAt
        match.endedAt = session.endedAt ?? Date()
        match.durationSeconds = Int((session.endedAt ?? Date()).timeIntervalSince(session.startedAt))
        match.mode = session.options.mode.rawValue
        match.noAdRule = session.options.noAdRule
        match.resultRaw = session.result?.rawValue ?? "win"
        match.myTotalSets = session.mySetScore
        match.yourTotalSets = session.yourSetScore
        match.averageHeartRate = session.averageHeartRate
        match.caloriesBurned = (session.kcalAtEnd ?? 0) - session.kcalAtStart
        match.sets = session.completedSets.enumerated().map {
            SetRecord(myGames: $0.element.my, yourGames: $0.element.your, setNumber: $0.offset + 1)
        }
        try MatchPersistenceService.shared.save(match)
    }

    func startNewMatch() {
        _currentSession = nil
        phase = .modeSelection
    }

    func restartMatch() {
        guard let options = _currentSession?.options else { return }
        startMatch(options: options)
    }

    func pauseWorkout() { healthKit.pauseWorkout() }
    func resumeWorkout() { healthKit.resumeWorkout() }

    func endWorkout() {
        _currentSession = nil
        appGroupDefaults?.set(false, forKey: "isWorkoutActive")
        WidgetCenter.shared.reloadTimelines(ofKind: "ComplicationApp")
        connectivity.sendWorkoutEnd()
        Task { _ = await healthKit.stopWorkout() }
    }

    func broadcastMetrics() {
        guard case .playing = phase else { return }
        let kcalStart = _currentSession?.kcalAtStart ?? 0
        let metrics = WorkoutMetrics(
            elapsedSeconds: TimeInterval(healthKit.elapsedSeconds),
            calories: healthKit.currentCalories - kcalStart,
            heartRate: healthKit.currentHeartRate,
            steps: 0
        )
        lastMetrics = metrics
        connectivity.sendMetrics(metrics)
    }

    private func sendMatchEndToiOS(session: MatchSession) {
        let msg = MatchEndMessage(
            sessionId: session.workoutSessionId,
            result: session.result?.rawValue ?? "win",
            completedSets: session.completedSets.map { [$0.my, $0.your] },
            startedAt: session.startedAt,
            endedAt: session.endedAt ?? Date(),
            calories: (session.kcalAtEnd ?? 0) - session.kcalAtStart,
            averageHeartRate: session.averageHeartRate,
            mode: session.options.mode.rawValue,
            noAdRule: session.options.noAdRule
        )
        connectivity.sendMatchEnd(msg)
    }
}
