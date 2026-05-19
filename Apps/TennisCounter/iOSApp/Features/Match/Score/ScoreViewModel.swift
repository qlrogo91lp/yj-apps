import Combine
import Foundation

@MainActor
final class ScoreViewModel: ObservableObject {
    let options: MatchOptions

    @Published var score = Score()
    @Published var myGameScore: Int = 0
    @Published var yourGameScore: Int = 0
    @Published var mySetScore: Int = 0
    @Published var yourSetScore: Int = 0
    @Published var currentSetNumber: Int = 1
    @Published var completedSets: [(my: Int, your: Int)] = []
    @Published var isMatchOver: Bool = false
    @Published var didWin: Bool = false

    var isTieBreak: Bool { score.gameMode == .tieBreak }

    var hasProgress: Bool {
        myGameScore > 0 || yourGameScore > 0 ||
        mySetScore > 0 || yourSetScore > 0 ||
        !completedSets.isEmpty ||
        score.lastAction != .none
    }

    private var isApplyingRemote = false
    private var cancellables = Set<AnyCancellable>()
    private let connectivity = WatchConnectivityService.shared

    init(options: MatchOptions = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)) {
        self.options = options
        self.score.noAdRule = options.noAdRule

        score.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        connectivity.$receivedScoreState
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.applyRemoteState(state) }
            .store(in: &cancellables)

        // Watch 재연결 시 현재 상태 즉시 전송
        connectivity.$isWatchReachable
            .filter { $0 }
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
        sendScoreState()
        LiveActivityService.shared.update(from: makeScoreState(), score: score)
        checkSetUpdate()
        if myGameScore == 6 && yourGameScore == 6 && !options.noTieRule {
            score.setTieBreakMode()
        }
    }

    func undo() {
        score.undo()
    }

    func resetAll() {
        myGameScore = 0
        yourGameScore = 0
        mySetScore = 0
        yourSetScore = 0
        currentSetNumber = 1
        completedSets = []
        isMatchOver = false
        didWin = false
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
        LiveActivityService.shared.update(from: state, score: score)
        isApplyingRemote = false
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

    private func checkSetUpdate() {
        guard isSetComplete() else { return }
        let myWonSet = myGameScore > yourGameScore
        completedSets.append((my: myGameScore, your: yourGameScore))
        if myWonSet { mySetScore += 1 } else { yourSetScore += 1 }
        myGameScore = 0
        yourGameScore = 0
        currentSetNumber += 1
        if mySetScore >= options.mode.setsToWin {
            didWin = true
            isMatchOver = true
        } else if yourSetScore >= options.mode.setsToWin {
            didWin = false
            isMatchOver = true
        }
    }

    private func isSetComplete() -> Bool {
        let maxGames = max(myGameScore, yourGameScore)
        let minGames = min(myGameScore, yourGameScore)
        if maxGames == 7 && minGames == 6 { return true }
        return maxGames >= 6 && (maxGames - minGames) >= 2
    }
}
