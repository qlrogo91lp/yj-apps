import Combine
import SwiftUI

class ScoreViewModel: ObservableObject {
    @Published var score = Score()
    @Published var myGameScore: Int = 0
    @Published var yourGameScore: Int = 0
    @Published var mySetScore: Int = 0
    @Published var yourSetScore: Int = 0
    @Published var completedSets: [SetScore] = []

    let options: MatchOptions
    var onMatchFinished: ((MatchResult, [SetScore]) -> Void)?

    private var isApplyingRemote = false
    private var tieBreakInProgress: Bool = false
    private var cancellables = Set<AnyCancellable>()
    private let connectivity = WatchConnectivityService.shared

    init(options: MatchOptions) {
        self.options = options
        score.noAdRule = options.noAdRule

        score.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        connectivity.$receivedScoreState
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.applyRemoteState(state) }
            .store(in: &cancellables)
    }

    func addPoint(_ side: PlayerSide) {
        guard score.addPoint(side) != nil else { return }
        withAnimation(.bouncy) {
            if side == .me { myGameScore += 1 } else { yourGameScore += 1 }
        }
        score.reset()
        sendScoreState()
        checkSetUpdate()
    }

    func undo() {
        score.undo()
    }

    func applyRemoteState(_ state: ScoreState) {
        isApplyingRemote = true
        myGameScore = state.myGameScore
        yourGameScore = state.yourGameScore
        mySetScore = state.mySetScore
        yourSetScore = state.yourSetScore
        completedSets = state.completedSets.map { SetScore(my: $0[0], your: $0[1]) }
        score.applyRemote(myScore: state.myScore, yourScore: state.yourScore, isTieBreak: state.isTieBreak)
        tieBreakInProgress = state.isTieBreak
        isApplyingRemote = false
    }

    private func sendScoreState() {
        guard !isApplyingRemote else { return }
        let myScore = score.gameMode == .tieBreak ? score.myTieBreak : score.myScore
        let yourScore = score.gameMode == .tieBreak ? score.yourTieBreak : score.yourScore
        connectivity.sendScoreState(ScoreState(
            myScore: myScore,
            yourScore: yourScore,
            myGameScore: myGameScore,
            yourGameScore: yourGameScore,
            mySetScore: mySetScore,
            yourSetScore: yourSetScore,
            completedSets: completedSets.map { [$0.my, $0.your] },
            isTieBreak: score.gameMode == .tieBreak
        ))
    }

    private func checkSetUpdate() {
        let my = myGameScore, your = yourGameScore

        if tieBreakInProgress {
            if (my == 7 && your == 6) || (your == 7 && my == 6) {
                tieBreakInProgress = false
                let winner: PlayerSide = my == 7 ? .me : .opponent
                finalizeSet(winner: winner)
            }
            return
        }

        if !options.noTieRule, my == 6, your == 6 {
            score.setTieBreakMode()
            tieBreakInProgress = true
            return
        }

        let maxG = max(my, your), minG = min(my, your)
        let setWinner: PlayerSide? = if options.noTieRule {
            if my >= 6, my > your { .me } else if your >= 6, your > my { .opponent } else { nil }
        } else {
            if maxG >= 6, (maxG - minG) >= 2 { my > your ? .me : .opponent } else { nil }
        }

        if let winner = setWinner { finalizeSet(winner: winner) }
    }

    private func finalizeSet(winner: PlayerSide) {
        completedSets.append(SetScore(my: myGameScore, your: yourGameScore))
        if winner == .me { mySetScore += 1 } else { yourSetScore += 1 }
        myGameScore = 0
        yourGameScore = 0

        let setsToWin = options.mode.setsToWin
        if mySetScore >= setsToWin {
            onMatchFinished?(.win, completedSets)
        } else if yourSetScore >= setsToWin {
            onMatchFinished?(.loss, completedSets)
        }
    }
}
