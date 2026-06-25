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
    let scoreVM = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
    private(set) var isDriver = false

    init(metricsThrottle: TimeInterval = 5) {
        self.metricsThrottle = metricsThrottle
        healthKit.$isPaused
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPaused)

        connectivity.$receivedSessionStart
            .compactMap(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in
                guard let self else { return }
                if case .playing = phase { return }
                if !healthKit.isWorkoutActive { startWorkout() }
                startMatch(options: msg.options, sessionId: msg.sessionId, isRemote: true)
            }
            .store(in: &cancellables)

        connectivity.$receivedWorkoutEnd
            .compactMap(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                endWorkout(notifyRemote: false)
                remoteWorkoutEnded = true
            }
            .store(in: &cancellables)

        healthKit.$currentHeartRate
            .dropFirst()
            .throttle(for: .seconds(metricsThrottle), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                guard let self, case .playing = self.phase else { return }
                broadcastMetrics()
            }
            .store(in: &cancellables)

        scoreVM.onMatchFinished = { [weak self] result, sets in
            self?.finishMatch(result: result, completedSets: sets)
        }

        scoreVM.onStateChanged = { [weak self] in
            guard let self, self.isDriver else { return }
            self.connectivity.sendScoreState(self.scoreVM.makeScoreState())
        }

        connectivity.$receivedScoreState
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.handleIncomingScoreState(state) }
            .store(in: &cancellables)

        connectivity.$isWatchReachable
            .filter(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, isDriver, case .playing = phase else { return }
                connectivity.sendScoreState(scoreVM.makeScoreState())
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
        isDriver = !isRemote
        let id = sessionId ?? workoutSessionId
        let session = MatchSession(
            workoutSessionId: id,
            options: options,
            kcalAtStart: healthKit.currentCalories
        )
        _currentSession = session

        if !isRemote {
            connectivity.receivedScoreState = nil
        }

        scoreVM.resetAll(options: options)
        phase = .playing(options)

        if !isRemote {
            connectivity.sendSessionStart(SessionStartMessage(
                sessionId: id,
                options: options,
                workoutStartDate: healthKit.startDate ?? Date()
            ))
        }
    }

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
            sendMatchEndToiOS(session: session)
        }
    }

    /// Watch엔 로컬 저장소가 없다. 저장 버튼 → iOS에 저장 요청을 보내고 iOS가 히스토리에 persist 한다.
    func saveCurrentMatch() {
        guard let session = _currentSession else { return }
        connectivity.sendMatchSave(makeMatchEndMessage(session: session))
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

    func endWorkout(notifyRemote: Bool = true) {
        _currentSession = nil
        appGroupDefaults?.set(false, forKey: "isWorkoutActive")
        WidgetCenter.shared.reloadTimelines(ofKind: "ComplicationApp")
        if notifyRemote { connectivity.sendWorkoutEnd() }
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

    private func handleIncomingScoreState(_ state: ScoreState) {
        guard !isDriver else { return }
        scoreVM.applyRemoteState(state)
    }

    #if DEBUG
    func applyIncomingScoreStateForTest(_ state: ScoreState) { handleIncomingScoreState(state) }
    #endif

    private func sendMatchEndToiOS(session: MatchSession) {
        connectivity.sendMatchEnd(makeMatchEndMessage(session: session))
    }

    private func makeMatchEndMessage(session: MatchSession) -> MatchEndMessage {
        MatchEndMessage(
            sessionId: session.workoutSessionId,
            result: session.result?.rawValue ?? "win",
            completedSets: session.completedSets.map { [$0.my, $0.your] },
            startedAt: session.startedAt,
            endedAt: session.endedAt ?? Date(),
            durationSeconds: healthKit.elapsedSeconds,
            calories: (session.kcalAtEnd ?? 0) - session.kcalAtStart,
            averageHeartRate: session.averageHeartRate,
            mode: session.options.mode.rawValue,
            noAdRule: session.options.noAdRule
        )
    }
}
