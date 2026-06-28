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
    private var pausedAt: Date?
    private var totalPausedSeconds: TimeInterval = 0
    private var sessionId: UUID = .init()
    private var hasSyncedSession = false
    private var _currentSession: MatchSession?
    let scoreVM = ScoreViewModel()
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let connectivity = WatchConnectivityService.shared
    private let liveActivity: LiveActivityControlling
    private(set) var isDriver = false

    init(liveActivity: LiveActivityControlling = LiveActivityService.shared) {
        self.liveActivity = liveActivity
        setupScoreSync()
        setupConnectivityBindings()
    }

    private func setupScoreSync() {
        connectivity.$isWatchReachable
            .filter(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, isDriver, case let .playing(options) = phase else { return }
                connectivity.sendSessionStart(SessionStartMessage(
                    sessionId: sessionId,
                    options: options,
                    workoutStartDate: startedAt ?? Date()
                ))
                connectivity.sendScoreState(scoreVM.makeScoreState())
            }
            .store(in: &cancellables)

        scoreVM.onStateChanged = { [weak self] in
            guard let self else { return }
            let state = scoreVM.makeScoreState()
            liveActivity.update(from: state, score: scoreVM.score)
            guard isDriver else { return }
            connectivity.sendScoreState(state)
        }

        connectivity.$receivedScoreState
            .compactMap(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.handleIncomingScoreState(state) }
            .store(in: &cancellables)
    }

    private func setupConnectivityBindings() {
        connectivity.$isWatchReachable
            .receive(on: DispatchQueue.main)
            .assign(to: &$watchConnected)

        connectivity.$receivedMetrics
            .compactMap(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] received in
                guard let self else { return }
                metrics = WorkoutMetrics(
                    elapsedSeconds: TimeInterval(elapsedSeconds),
                    calories: received.calories,
                    heartRate: received.heartRate,
                    steps: received.steps
                )
            }
            .store(in: &cancellables)

        setupMatchLifecycleBindings()
    }

    private func setupMatchLifecycleBindings() {
        connectivity.$receivedSessionStart
            .compactMap(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in self?.handleIncomingSessionStart(msg) }
            .store(in: &cancellables)

        connectivity.$receivedMatchEnd
            .compactMap(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in
                guard let self else { return }
                // 경기 종료 = 결과 화면 표시만. 저장은 사용자가 저장 버튼을 누를 때(receivedMatchSave)만 한다.
                liveActivity.end()
                let session = buildSession(from: msg)
                completedMatchCount += 1
                phase = .finished(session)
            }
            .store(in: &cancellables)

        connectivity.$receivedMatchSave
            .compactMap(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in
                self?.saveFromWatch(msg)
            }
            .store(in: &cancellables)

        connectivity.$receivedWorkoutEnd
            .compactMap(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] id in self?.handleIncomingWorkoutEnd(id) }
            .store(in: &cancellables)

        connectivity.$receivedMatchReset
            .compactMap(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] id in self?.handleIncomingMatchReset(id) }
            .store(in: &cancellables)
    }

    private func handleIncomingMatchReset(_ id: UUID) {
        guard !isDriver else { return }
        if hasSyncedSession, id != sessionId { return }
        connectivity.receivedMatchReset = nil
        startNewMatch(notifyRemote: false)
    }

    private func handleIncomingWorkoutEnd(_ id: UUID) {
        // 매치가 한 번도 시작되지 않았으면 sessionId가 아직 상대와 동기화되지 않았으므로 무조건 수용한다.
        if hasSyncedSession, id != sessionId { return }
        connectivity.receivedWorkoutEnd = nil
        endSession(notifyRemote: false)
        remoteWorkoutEnded = true
    }

    deinit { timer?.invalidate() }

    func startSession(startDate: Date = Date()) {
        startedAt = startDate
        totalPausedSeconds = 0
        pausedAt = nil
        startTimer()
    }

    func pauseSession() {
        isPaused = true
        pausedAt = Date()
        timer?.invalidate()
        timer = nil
    }

    func resumeSession() {
        if let p = pausedAt {
            totalPausedSeconds += Date().timeIntervalSince(p)
            pausedAt = nil
        }
        isPaused = false
        startTimer()
    }

    func startMatch(options: MatchOptions, sessionId: UUID? = nil, isRemote: Bool = false) {
        isDriver = !isRemote
        hasSyncedSession = true
        // 원격 채택 시 자기 sessionId를 상대 것으로 맞춘다. 안 그러면 workoutEnd·matchReset
        // 같은 sessionId 가드가 걸린 신호를 init UUID와 불일치로 모두 무시해버린다.
        if let sessionId { self.sessionId = sessionId }
        _currentSession = MatchSession(
            workoutSessionId: self.sessionId,
            options: options,
            startedAt: startedAt ?? Date(),
            kcalAtStart: 0
        )

        if !isRemote {
            connectivity.receivedScoreState = nil
        }

        scoreVM.resetAll(options: options)
        phase = .playing(options)
        liveActivity.start(mode: options.mode)

        if !isRemote {
            connectivity.sendSessionStart(SessionStartMessage(
                sessionId: self.sessionId,
                options: options,
                workoutStartDate: startedAt ?? Date()
            ))
        }
    }

    func finishMatch(result: MatchResult, completedSets: [(my: Int, your: Int)]) {
        guard let session = _currentSession else { return }
        session.endedAt = Date()
        session.result = result
        let setScores = completedSets.map { SetScore(my: $0.my, your: $0.your) }
        session.completedSets = setScores
        session.mySetScore = setScores.count(where: { $0.my > $0.your })
        session.yourSetScore = setScores.count(where: { $0.your > $0.my })
        session.kcalAtEnd = metrics.calories
        completedMatchCount += 1
        phase = .finished(session)
        liveActivity.end()
    }

    @discardableResult
    func saveCurrentMatch() -> Bool {
        guard let session = _currentSession else { return false }
        let match = buildMatchFromSession(session)
        do {
            try MatchPersistenceService.shared.upsert(match)
            return true
        } catch {
            return false
        }
    }

    func restartMatch() {
        guard let options = _currentSession?.options else { return }
        startMatch(options: options, isRemote: !isDriver)
    }

    func startNewMatch(notifyRemote: Bool = true) {
        if notifyRemote, isDriver, case .playing = phase {
            connectivity.sendMatchReset(sessionId: sessionId)
        }
        _currentSession = nil
        phase = .modeSelection
    }

    func endSession(notifyRemote: Bool = true) {
        timer?.invalidate()
        timer = nil
        elapsedSeconds = 0
        totalPausedSeconds = 0
        pausedAt = nil
        metrics = .init()
        _currentSession = nil
        phase = .modeSelection
        liveActivity.end()
        connectivity.clearSessionContext()
        if notifyRemote { connectivity.sendWorkoutEnd(sessionId: sessionId) }
    }

    // MARK: - Private

    private func handleIncomingSessionStart(_ msg: SessionStartMessage) {
        if case .playing = phase {
            // 동시 시작 race: 이미 driver로 진행 중이면 더 작은 sessionId 쪽이 우선권을 가진다.
            guard isDriver, msg.sessionId.uuidString < sessionId.uuidString else { return }
        }
        sessionId = msg.sessionId
        startSession(startDate: msg.workoutStartDate)
        startMatch(options: msg.options, isRemote: true)
    }

    private func handleIncomingScoreState(_ state: ScoreState) {
        guard !isDriver, case .playing = phase else { return }
        scoreVM.applyRemoteState(state)
        liveActivity.update(from: state, score: scoreVM.score)
    }

    private func saveFromWatch(_ msg: MatchEndMessage) {
        let match = buildMatchFromMessage(msg)
        var success = true
        do { try MatchPersistenceService.shared.upsert(match) } catch { success = false }
        connectivity.sendMatchSaveResult(MatchSaveResultMessage(sessionId: msg.sessionId, success: success))
    }

    private func buildMatchFromMessage(_ msg: MatchEndMessage) -> Match {
        let match = Match()
        match.workoutSessionId = msg.sessionId
        match.startedAt = msg.startedAt
        match.endedAt = msg.endedAt
        match.durationSeconds = msg.durationSeconds
        match.caloriesBurned = msg.calories
        match.averageHeartRate = msg.averageHeartRate
        match.mode = msg.mode
        match.noAdRule = msg.noAdRule
        match.resultRaw = msg.result
        match.myTotalSets = msg.completedSets.count(where: { $0[0] > $0[1] })
        match.yourTotalSets = msg.completedSets.count(where: { $0[1] > $0[0] })
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
        match.durationSeconds = elapsedSeconds
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
        session.result = MatchResult(rawValue: msg.result) ?? .loss
        session.completedSets = msg.completedSets.map { SetScore(my: $0[0], your: $0[1]) }
        session.mySetScore = msg.completedSets.count(where: { $0[0] > $0[1] })
        session.yourSetScore = msg.completedSets.count(where: { $0[1] > $0[0] })
        session.kcalAtEnd = msg.calories
        session.averageHeartRate = msg.averageHeartRate
        return session
    }

    private func startTimer() {
        timer?.invalidate()
        guard let startedAt else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                elapsedSeconds = Int(Date().timeIntervalSince(startedAt) - totalPausedSeconds)
                metrics = WorkoutMetrics(
                    elapsedSeconds: TimeInterval(elapsedSeconds),
                    calories: metrics.calories,
                    heartRate: metrics.heartRate,
                    steps: metrics.steps
                )
            }
        }
    }
}

#if DEBUG
    extension WorkoutSessionViewModel {
        func handleIncomingWorkoutEndForTest(_ id: UUID) {
            handleIncomingWorkoutEnd(id)
        }

        func handleIncomingMatchResetForTest(_ id: UUID) {
            handleIncomingMatchReset(id)
        }

        var currentSessionIdForTest: UUID {
            sessionId
        }

        func applyIncomingScoreStateForTest(_ state: ScoreState) {
            handleIncomingScoreState(state)
        }

        func applyIncomingSessionStartForTest(_ msg: SessionStartMessage) {
            handleIncomingSessionStart(msg)
        }

        func saveFromWatchForTest(_ msg: MatchEndMessage) {
            saveFromWatch(msg)
        }
    }
#endif
