import Combine
import Foundation

@MainActor
final class ScoreViewModel: ObservableObject {
    @Published private(set) var options: MatchOptions

    @Published var score = Score()
    @Published var myGameScore: Int = 0
    @Published var yourGameScore: Int = 0
    @Published var mySetScore: Int = 0
    @Published var yourSetScore: Int = 0
    @Published var currentSetNumber: Int = 1
    @Published var completedSets: [(my: Int, your: Int)] = []
    @Published private(set) var matchResult: MatchResult?

    var isMatchOver: Bool {
        matchResult != nil
    }

    var didWin: Bool {
        matchResult == .win
    }

    var isTieBreak: Bool {
        score.gameMode == .tieBreak
    }

    var hasProgress: Bool {
        myGameScore > 0 || yourGameScore > 0 ||
            mySetScore > 0 || yourSetScore > 0 ||
            !completedSets.isEmpty ||
            score.lastAction != .none
    }

    private var tieBreakInProgress = false
    private var isApplyingRemote = false
    private var cancellables = Set<AnyCancellable>()
    private let connectivity = WatchConnectivityService.shared

    init(options: MatchOptions = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)) {
        self.options = options
        score.noAdRule = options.noAdRule

        score.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        connectivity.$receivedScoreState
            .compactMap(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.applyRemoteState(state) }
            .store(in: &cancellables)

        connectivity.$isWatchReachable
            .filter(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.sendScoreState() }
            .store(in: &cancellables)
    }

    func addPoint(_ side: PlayerSide) {
        guard !isMatchOver else { return }
        let gameWon = score.addPoint(side)
        LiveActivityService.shared.update(from: makeScoreState(), score: score)
        guard gameWon != nil else { return }
        if side == .me { myGameScore += 1 } else { yourGameScore += 1 }
        score.resetData()
        checkSetUpdate()
        sendScoreState()
        LiveActivityService.shared.update(from: makeScoreState(), score: score)
    }

    func undo() {
        score.undo()
    }

    func resetAll(options: MatchOptions) {
        self.options = options
        myGameScore = 0
        yourGameScore = 0
        mySetScore = 0
        yourSetScore = 0
        currentSetNumber = 1
        completedSets = []
        matchResult = nil
        tieBreakInProgress = false
        score.noAdRule = options.noAdRule
        score.resetData()
    }

    func applyRemoteState(_ state: ScoreState) {
        isApplyingRemote = true
        myGameScore = state.myGameScore
        yourGameScore = state.yourGameScore
        mySetScore = state.mySetScore
        yourSetScore = state.yourSetScore
        completedSets = state.completedSets.map { (my: $0[0], your: $0[1]) }
        score.applyRemote(myScore: state.myScore, yourScore: state.yourScore, isTieBreak: state.isTieBreak)
        tieBreakInProgress = state.isTieBreak
        LiveActivityService.shared.update(from: state, score: score)
        isApplyingRemote = false
    }

    // MARK: - Private

    private func checkSetUpdate() {
        let threshold = options.gameThreshold
        let my = myGameScore, your = yourGameScore

        if tieBreakInProgress {
            if (my == threshold + 1 && your == threshold) || (your == threshold + 1 && my == threshold) {
                tieBreakInProgress = false
                finalizeSet(winner: my > your ? .me : .opponent)
            }
            return
        }

        if my == threshold, your == threshold {
            if options.noTieRule {
                completedSets.append((my: my, your: your))
                matchResult = .draw
            } else {
                score.setTieBreakMode()
                tieBreakInProgress = true
            }
            return
        }

        let maxG = max(my, your), minG = min(my, your)
        guard maxG >= threshold, (maxG - minG) >= 2 else { return }
        finalizeSet(winner: my > your ? .me : .opponent)
    }

    private func finalizeSet(winner: PlayerSide) {
        completedSets.append((my: myGameScore, your: yourGameScore))
        if winner == .me { mySetScore += 1 } else { yourSetScore += 1 }
        myGameScore = 0
        yourGameScore = 0
        currentSetNumber += 1

        if mySetScore >= options.mode.setsToWin {
            matchResult = .win
        } else if yourSetScore >= options.mode.setsToWin {
            matchResult = .loss
        }
    }

    private func makeScoreState() -> ScoreState {
        let myS = score.gameMode == .tieBreak ? score.myTieBreak : score.myScore
        let yourS = score.gameMode == .tieBreak ? score.yourTieBreak : score.yourScore
        return ScoreState(
            myScore: myS, yourScore: yourS,
            myGameScore: myGameScore, yourGameScore: yourGameScore,
            mySetScore: mySetScore, yourSetScore: yourSetScore,
            completedSets: completedSets.map { [$0.my, $0.your] },
            isTieBreak: score.gameMode == .tieBreak
        )
    }

    private func sendScoreState() {
        guard !isApplyingRemote else { return }
        connectivity.sendScoreState(makeScoreState())
    }
}
