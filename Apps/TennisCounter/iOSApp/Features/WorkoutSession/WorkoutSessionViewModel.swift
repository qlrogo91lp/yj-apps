import Combine
import Foundation

@MainActor
class WorkoutSessionViewModel: ObservableObject {
    @Published var phase: MatchPhase = .modeSelection
    @Published var elapsedSeconds: Int = 0
    @Published var metrics: WorkoutMetrics = .init()
    @Published var watchConnected: Bool = false
    @Published var isPaused: Bool = false
    @Published var completedMatchCount: Int = 0
    @Published var remoteWorkoutEnded: Bool = false

    private var startedAt: Date?
    private var sessionId: UUID = .init()
    private var _currentSession: MatchSession?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let connectivity = WatchConnectivityService.shared

    init() {
        connectivity.$isWatchReachable
            .receive(on: DispatchQueue.main)
            .assign(to: &$watchConnected)

        connectivity.$receivedMetrics
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] received in
                guard let self else { return }
                self.metrics = WorkoutMetrics(
                    elapsedSeconds: TimeInterval(self.elapsedSeconds),
                    calories: received.calories,
                    heartRate: received.heartRate,
                    steps: received.steps
                )
            }
            .store(in: &cancellables)

        connectivity.$receivedSessionStart
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in
                guard let self else { return }
                self.sessionId = msg.sessionId
                self.startSession()
                self.startMatch(options: msg.options, isRemote: true)
                LiveActivityService.shared.start(mode: msg.options.mode)
            }
            .store(in: &cancellables)

        connectivity.$receivedMatchEnd
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in
                guard let self else { return }
                self.saveFromWatch(msg)
                LiveActivityService.shared.end()
                let session = self.buildSession(from: msg)
                self.completedMatchCount += 1
                self.phase = .finished(session)
            }
            .store(in: &cancellables)

        connectivity.$receivedWorkoutEnd
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.endSession()
                self.remoteWorkoutEnded = true
            }
            .store(in: &cancellables)
    }

    deinit { timer?.invalidate() }

    func startSession() {
        startedAt = Date()
        startTimer()
    }

    func pauseSession() {
        isPaused = true
        timer?.invalidate()
        timer = nil
    }

    func resumeSession() {
        isPaused = false
        startTimer()
    }

    func startMatch(options: MatchOptions, isRemote: Bool = false) {
        _currentSession = MatchSession(
            workoutSessionId: sessionId,
            options: options,
            startedAt: startedAt ?? Date(),
            kcalAtStart: 0
        )
        phase = .playing(options)
        LiveActivityService.shared.start(mode: options.mode)

        if !isRemote {
            connectivity.sendSessionStart(SessionStartMessage(sessionId: sessionId, options: options))
        }
    }

    func finishMatch(didWin: Bool, completedSets: [(my: Int, your: Int)]) {
        guard let session = _currentSession else { return }
        session.endedAt = Date()
        session.result = didWin ? .win : .loss
        let setScores = completedSets.map { SetScore(my: $0.my, your: $0.your) }
        session.completedSets = setScores
        session.mySetScore = setScores.filter { $0.my > $0.your }.count
        session.yourSetScore = setScores.filter { $0.your > $0.my }.count
        session.kcalAtEnd = metrics.calories
        completedMatchCount += 1
        phase = .finished(session)
        LiveActivityService.shared.end()
        saveCurrentMatch()
    }

    func saveCurrentMatch() {
        guard let session = _currentSession else { return }
        let match = buildMatchFromSession(session)
        try? MatchPersistenceService.shared.save(match)
    }

    func restartMatch() {
        guard let options = _currentSession?.options else { return }
        startMatch(options: options)
    }

    func startNewMatch() {
        _currentSession = nil
        phase = .modeSelection
    }

    func endSession() {
        timer?.invalidate()
        timer = nil
        elapsedSeconds = 0
        metrics = .init()
        _currentSession = nil
        phase = .modeSelection
        LiveActivityService.shared.end()
        connectivity.sendWorkoutEnd()
    }

    // MARK: - Private

    private func saveFromWatch(_ msg: MatchEndMessage) {
        let match = buildMatchFromMessage(msg)
        try? MatchPersistenceService.shared.save(match)
    }

    private func buildMatchFromMessage(_ msg: MatchEndMessage) -> Match {
        let match = Match()
        match.workoutSessionId = msg.sessionId
        match.startedAt = msg.startedAt
        match.endedAt = msg.endedAt
        match.durationSeconds = Int(msg.endedAt.timeIntervalSince(msg.startedAt))
        match.caloriesBurned = msg.calories
        match.averageHeartRate = msg.averageHeartRate
        match.mode = msg.mode
        match.noAdRule = msg.noAdRule
        match.resultRaw = msg.result
        match.myTotalSets = msg.completedSets.filter { $0[0] > $0[1] }.count
        match.yourTotalSets = msg.completedSets.filter { $0[1] > $0[0] }.count
        match.sets = msg.completedSets.enumerated().map {
            SetRecord(myGames: $0.element[0], yourGames: $0.element[1], setNumber: $0.offset + 1)
        }
        return match
    }

    private func buildMatchFromSession(_ session: MatchSession) -> Match {
        let match = Match()
        match.workoutSessionId = session.workoutSessionId
        match.startedAt = session.startedAt
        match.endedAt = session.endedAt ?? Date()
        match.durationSeconds = Int((session.endedAt ?? Date()).timeIntervalSince(session.startedAt))
        match.caloriesBurned = (session.kcalAtEnd ?? 0) - session.kcalAtStart
        match.mode = session.options.mode.rawValue
        match.noAdRule = session.options.noAdRule
        match.resultRaw = session.result?.rawValue ?? "win"
        match.myTotalSets = session.mySetScore
        match.yourTotalSets = session.yourSetScore
        match.sets = session.completedSets.enumerated().map {
            SetRecord(myGames: $0.element.my, yourGames: $0.element.your, setNumber: $0.offset + 1)
        }
        return match
    }

    private func buildSession(from msg: MatchEndMessage) -> MatchSession {
        let options = MatchOptions(
            mode: MatchFormat(rawValue: msg.mode) ?? .oneSet,
            noAdRule: msg.noAdRule,
            noTieRule: false
        )
        let session = MatchSession(
            workoutSessionId: msg.sessionId,
            options: options,
            startedAt: msg.startedAt,
            kcalAtStart: 0
        )
        session.endedAt = msg.endedAt
        session.result = msg.result == "win" ? .win : .loss
        session.completedSets = msg.completedSets.map { SetScore(my: $0[0], your: $0[1]) }
        session.mySetScore = msg.completedSets.filter { $0[0] > $0[1] }.count
        session.yourSetScore = msg.completedSets.filter { $0[1] > $0[0] }.count
        session.kcalAtEnd = msg.calories
        session.averageHeartRate = msg.averageHeartRate
        return session
    }

    private func startTimer() {
        timer?.invalidate()
        guard let startedAt else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isPaused else { return }
                self.elapsedSeconds = Int(Date().timeIntervalSince(startedAt))
                self.metrics = WorkoutMetrics(
                    elapsedSeconds: TimeInterval(self.elapsedSeconds),
                    calories: self.metrics.calories,
                    heartRate: self.metrics.heartRate,
                    steps: self.metrics.steps
                )
            }
        }
    }
}
