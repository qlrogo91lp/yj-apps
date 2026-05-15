import Combine
import Foundation

@MainActor
class WorkoutSessionViewModel: ObservableObject {
    @Published var phase: MatchPhase = .modeSelection
    @Published var elapsedSeconds: Int = 0
    @Published var metrics: WorkoutMetrics = .init()
    @Published var watchConnected: Bool = false
    @Published var isPaused: Bool = false

    private var startedAt: Date?
    private let sessionId: UUID = .init()
    private var currentOptions: MatchOptions?
    private var _currentSession: MatchSession?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init() {
        let connectivity = WatchConnectivityService.shared

        connectivity.$isWatchReachable
            .receive(on: DispatchQueue.main)
            .assign(to: &$watchConnected)

        connectivity.$receivedMetrics
            .receive(on: DispatchQueue.main)
            .compactMap(\.self)
            .sink { [weak self] received in
                guard let self else { return }
                self.metrics = WorkoutMetrics(
                    elapsedSeconds: TimeInterval(self.elapsedSeconds),
                    calories: received.calories,
                    heartRate: received.heartRate
                )
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

    func startMatch(options: MatchOptions) {
        currentOptions = options
        _currentSession = MatchSession(
            workoutSessionId: sessionId,
            options: options,
            startedAt: startedAt ?? Date(),
            kcalAtStart: 0
        )
        phase = .playing(options)
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
        phase = .finished(session)
    }

    func saveCurrentMatch() throws {
        guard let session = _currentSession else { return }
        let record = MatchRecord(from: session)
        try MatchPersistenceService.shared.save(record)
    }

    func restartMatch() {
        guard let options = _currentSession?.options else { return }
        startMatch(options: options)
    }

    func startNewMatch() {
        _currentSession = nil
        currentOptions = nil
        phase = .modeSelection
    }

    func endSession() {
        timer?.invalidate()
        timer = nil
        elapsedSeconds = 0
        metrics = .init()
        _currentSession = nil
        currentOptions = nil
        phase = .modeSelection
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
                    heartRate: self.metrics.heartRate
                )
            }
        }
    }
}
