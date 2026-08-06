import Combine
import Foundation
import WorkoutCore

@MainActor
class WorkoutSessionViewModel: ObservableObject {
    @Published var phase: MatchPhase = .modeSelection
    @Published var elapsedSeconds: Int = 0
    @Published var metrics: WorkoutMetrics = .init()
    @Published var watchConnected: Bool = false
    @Published var isPaused: Bool = false
    @Published var remoteWorkoutEnded: Bool = false

    private var startedAt: Date?
    private var anchor: WorkoutMetricsMessage?
    private var sessionId: UUID = .init()
    private var hasSyncedSession = false
    private var _currentSession: MatchSession?
    let scoreVM = ScoreViewModel()
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let connectivity = MatchConnectivity.shared
    private let liveActivity: LiveActivityControlling
    private(set) var isDriver = false

    /// 워치가 reachable하다는 것만으로는 pause 명령을 받아줄 워크아웃이 있다는 보장이 없다 —
    /// 워치로부터 앵커를 한 번이라도 받았어야(즉 실제로 브로드캐스트 중인 워크아웃이 있어야) 가용하다고 본다.
    var isPauseAvailable: Bool {
        watchConnected && anchor != nil
    }

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

        // 알려진 좁은 레이스: WorkoutMetricsMessage에는 세션 식별자가 없다. 워크아웃 경계 전환
        // (endSession()으로 이전 워크아웃이 완전히 끝난 뒤, 이어서 startSession()으로 새 워크아웃이
        // 시작되는 사이) — 이전(방금 끝난) 워크아웃에서 이미 인플라이트였던 메시지가
        // .receive(on: .main) 홉을 거쳐 두 리셋 이후에 도착하면 새 워크아웃의 anchor가 잠깐 이전
        // 워크아웃 값으로 덮어써질 수 있다 — elapsedSeconds가 그 이전 워크아웃의 경과시간(분 단위일 수도
        // 있음, 상한 없음)으로 튈 수 있다. 새 워치 브로드캐스트(주기 ~5s, metricsThrottle)가 도착하면
        // 즉시 올바른 anchor로 덮어써지므로 자가 치유되며, 지금까지 관측된 영향은 없다. 메시지에 세션
        // 식별자를 실어 이 메시지가 어느 세션 소속인지 판별하는 근본 수정은 WorkoutMetricsMessage
        // 와이어 포맷 변경(ralli-kit, 별도 태스크)이 필요해 이 태스크 범위 밖이다.
        // 같은 근본 원인(세션 식별자 부재)이 isPauseAvailable에도 좁게 걸쳐 있다: 워치 워크아웃이
        // 실행 중이지만 세션 동기화 전이면 pause 명령이 워치의 세션 가드에 막힌다 — 이 역시 별도 범위.
        // (2026-08-06 코드리뷰 finding, 문서화로 수용)
        connectivity.$receivedMetrics
            .compactMap(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] received in self?.applyIncomingMetrics(received) }
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
        anchor = nil
        startTimer()
    }

    /// 폰에는 워크아웃 세션이 없다 — 워치에 명령만 보낸다.
    /// isPaused는 워치가 보낸 앵커(ack)로만 바뀐다. 명령을 모르는 구버전 워치면 아무 일도 안 일어난다.
    func requestPause() {
        connectivity.sendPauseCommand(sessionId: sessionId, shouldPause: true)
    }

    func requestResume() {
        connectivity.sendPauseCommand(sessionId: sessionId, shouldPause: false)
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
            kcalAtStart: metrics.activeCalories,
            totalKcalAtStart: metrics.totalCalories
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
        session.kcalAtEnd = metrics.activeCalories
        // metrics.totalCalories는 WorkoutMetrics.totalCalories를 그대로 읽는데, 이 값은 워치로부터
        // totalCalories 키를 포함한 메트릭을 한 번도 못 받았을 때(구버전 워치 또는 폰 드라이버 경로에서
        // 워치 미연결) calories로 폴백한다. 이 경우 저장되는 Match.totalCaloriesBurned가 nil이 아니라
        // caloriesBurned와 같은 값이 되어, 워치발 MatchEndMessage.totalCalories 경로(정상적으로 nil 유지)와
        // 다르게 동작한다. 기존의 "메트릭 없을 때 caloriesBurned가 0으로 폴백"하는 동작과 대칭적인 accepted
        // limitation으로 현재 동작을 유지한다.
        session.totalKcalAtEnd = metrics.totalCalories
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
        anchor = nil
        metrics = .init()
        _currentSession = nil
        phase = .modeSelection
        liveActivity.end()
        connectivity.clearSessionContext()
        if notifyRemote { connectivity.sendWorkoutEnd(sessionId: sessionId) }
    }

    // MARK: - Private

    private func applyIncomingMetrics(_ msg: WorkoutMetricsMessage) {
        anchor = msg
        metrics = msg.metrics
        isPaused = msg.isPaused
        recomputeElapsed()
    }

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

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.recomputeElapsed() }
        }
    }

    /// 워치 앵커가 있으면 그 기준으로 보간하고, 없으면(폰 단독) 로컬 시작 시각으로 센다.
    private func recomputeElapsed(now: TimeInterval = Date().timeIntervalSince1970) {
        let seconds: TimeInterval = if let anchor {
            WorkoutAnchor.interpolatedElapsed(
                anchorElapsed: anchor.metrics.elapsedSeconds,
                isPaused: anchor.isPaused,
                sentAt: anchor.sentAt,
                now: now
            )
        } else if let startedAt {
            now - startedAt.timeIntervalSince1970
        } else {
            0
        }
        elapsedSeconds = Int(seconds)
        metrics = WorkoutMetrics(elapsedSeconds: seconds,
                                 activeCalories: metrics.activeCalories,
                                 totalCalories: metrics.totalCalories,
                                 heartRate: metrics.heartRate)
    }
}

// MARK: - Match building

private extension WorkoutSessionViewModel {
    func buildMatchFromMessage(_ msg: MatchEndMessage) -> Match {
        let match = Match()
        match.workoutSessionId = msg.sessionId
        match.startedAt = msg.startedAt
        match.endedAt = msg.endedAt
        match.durationSeconds = msg.durationSeconds
        match.caloriesBurned = msg.calories
        match.totalCaloriesBurned = msg.totalCalories
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

    func buildMatchFromSession(_ session: MatchSession) -> Match {
        let match = Match()
        match.workoutSessionId = session.workoutSessionId
        match.startedAt = session.startedAt
        match.endedAt = session.endedAt ?? Date()
        match.durationSeconds = elapsedSeconds
        match.caloriesBurned = (session.kcalAtEnd ?? 0) - session.kcalAtStart
        match.totalCaloriesBurned = session.totalKcalAtEnd.map { $0 - session.totalKcalAtStart }
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

    func buildSession(from msg: MatchEndMessage) -> MatchSession {
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
        session.totalKcalAtEnd = msg.totalCalories
        session.averageHeartRate = msg.averageHeartRate
        return session
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

        var currentSessionForTest: MatchSession? {
            _currentSession
        }

        func buildMatchForTest(_ session: MatchSession) -> Match {
            buildMatchFromSession(session)
        }

        func applyIncomingMetricsForTest(_ msg: WorkoutMetricsMessage) {
            applyIncomingMetrics(msg)
        }

        func recomputeElapsedForTest(now: TimeInterval) {
            recomputeElapsed(now: now)
        }
    }
#endif
