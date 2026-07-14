import Combine
import Foundation
import WidgetKit
import WorkoutCore

@MainActor
class WorkoutSessionViewModel: ObservableObject {
    @Published var phase: MatchPhase = .modeSelection
    @Published var isPaused: Bool = false
    @Published var remoteWorkoutEnded: Bool = false

    let healthKit: WorkoutSessionService
    let workoutSessionId: UUID = .init()
    @Published private(set) var lastMetrics: WorkoutMetrics?

    private let connectivity = WatchConnectivityService.shared
    private let appGroupDefaults = UserDefaults(suiteName: "group.com.yj.TennisCounter")
    private let metricsThrottle: TimeInterval
    private var cancellables = Set<AnyCancellable>()
    private var _currentSession: MatchSession?
    let scoreVM = ScoreViewModel(options: MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false))
    private(set) var isDriver = false
    private(set) var activeSessionId: UUID = .init()
    private var hasSyncedSession = false

    enum SaveAckState: Equatable {
        case idle, pending, succeeded, failed
    }

    @Published var saveAckState: SaveAckState = .idle
    private var saveAttemptToken = 0
    private let ackTimeoutSeconds: TimeInterval

    init(healthKit: WorkoutSessionService = WorkoutSessionService(configuration: .tennis),
         metricsThrottle: TimeInterval = 5, ackTimeoutSeconds: TimeInterval = 8)
    {
        self.healthKit = healthKit
        self.metricsThrottle = metricsThrottle
        self.ackTimeoutSeconds = ackTimeoutSeconds
        healthKit.$isPaused
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPaused)

        setupConnectivityBindings()
        setupScoreSync()

        healthKit.$currentHeartRate
            .dropFirst()
            .throttle(for: .seconds(metricsThrottle), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                guard let self, case .playing = self.phase else { return }
                broadcastMetrics()
            }
            .store(in: &cancellables)
    }

    private func setupConnectivityBindings() {
        connectivity.$receivedSessionStart
            .compactMap(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in self?.handleIncomingSessionStart(msg) }
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

        connectivity.$receivedMatchSaveResult
            .compactMap(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in self?.handleMatchSaveResult(result) }
            .store(in: &cancellables)
    }

    private func handleMatchSaveResult(_ result: MatchSaveResultMessage) {
        guard result.sessionId == activeSessionId else { return }
        guard saveAckState == .pending || saveAckState == .failed else { return }
        connectivity.receivedMatchSaveResult = nil
        saveAckState = result.success ? .succeeded : .failed
    }

    private func handleIncomingWorkoutEnd(_ id: UUID) {
        // 매치가 한 번도 시작되지 않았으면 sessionId가 아직 상대와 동기화되지 않았으므로 무조건 수용한다.
        if hasSyncedSession, id != activeSessionId { return }
        connectivity.receivedWorkoutEnd = nil
        endWorkout(notifyRemote: false)
        remoteWorkoutEnded = true
    }

    private func handleIncomingMatchReset(_ id: UUID) {
        guard !isDriver else { return }
        if hasSyncedSession, id != activeSessionId { return }
        connectivity.receivedMatchReset = nil
        startNewMatch(notifyRemote: false)
    }

    #if DEBUG
        func handleIncomingWorkoutEndForTest(_ id: UUID) {
            handleIncomingWorkoutEnd(id)
        }

        var activeSessionIdForTest: UUID {
            activeSessionId
        }
    #endif

    private func setupScoreSync() {
        scoreVM.onMatchFinished = { [weak self] result, sets in
            self?.finishMatch(result: result, completedSets: sets)
        }

        scoreVM.onStateChanged = { [weak self] in
            guard let self, isDriver else { return }
            connectivity.sendScoreState(scoreVM.makeScoreState())
        }

        connectivity.$receivedScoreState
            .compactMap(\.self)
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
        hasSyncedSession = true
        saveAckState = .idle
        saveAttemptToken += 1
        let id = sessionId ?? workoutSessionId
        activeSessionId = id
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
    /// iOS의 ack(`matchSaveResult`)를 받아 실제 결과를 반영하며, ackTimeoutSeconds 안에 ack가
    /// 없으면 failed로 전환한다. saveAttemptToken은 재시도로 새 시도가 시작된 뒤 이전 시도의
    /// 지연된 타임아웃이 새 상태를 덮어쓰지 않게 막는 표식이다.
    func saveCurrentMatch() {
        guard let session = _currentSession else { return }
        saveAttemptToken += 1
        let token = saveAttemptToken
        saveAckState = .pending
        connectivity.sendMatchSave(makeMatchEndMessage(session: session))
        DispatchQueue.main.asyncAfter(deadline: .now() + ackTimeoutSeconds) { [weak self] in
            guard let self, saveAttemptToken == token, saveAckState == .pending else { return }
            saveAckState = .failed
        }
    }

    func startNewMatch(notifyRemote: Bool = true) {
        if notifyRemote, isDriver, case .playing = phase {
            connectivity.sendMatchReset(sessionId: activeSessionId)
        }
        _currentSession = nil
        phase = .modeSelection
        saveAckState = .idle
        saveAttemptToken += 1
    }

    func restartMatch() {
        guard let options = _currentSession?.options else { return }
        startMatch(options: options, sessionId: activeSessionId, isRemote: !isDriver)
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
        connectivity.clearSessionContext()
        if notifyRemote { connectivity.sendWorkoutEnd(sessionId: activeSessionId) }
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

    private func handleIncomingSessionStart(_ msg: SessionStartMessage) {
        if case .playing = phase {
            // 동시 시작 race: 이미 driver로 진행 중이면 더 작은 sessionId 쪽이 우선권을 가진다.
            guard isDriver, msg.sessionId.uuidString < workoutSessionId.uuidString else { return }
        }
        if !healthKit.isWorkoutActive { startWorkout() }
        startMatch(options: msg.options, sessionId: msg.sessionId, isRemote: true)
    }

    private func handleIncomingScoreState(_ state: ScoreState) {
        guard !isDriver, case .playing = phase else { return }
        scoreVM.applyRemoteState(state)
    }

    #if DEBUG
        func applyIncomingScoreStateForTest(_ state: ScoreState) {
            handleIncomingScoreState(state)
        }

        func applyIncomingSessionStartForTest(_ msg: SessionStartMessage) {
            handleIncomingSessionStart(msg)
        }

        func handleMatchSaveResultForTest(_ result: MatchSaveResultMessage) {
            handleMatchSaveResult(result)
        }
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
