import Combine
import SwiftUI

class MatchViewModel: ObservableObject {
    @Published var score = Score()
    @Published var myGameScore: Int = 0
    @Published var yourGameScore: Int = 0
    @Published var mySetScore: Int = 0
    @Published var yourSetScore: Int = 0
    @Published var completedSets: [SetScore] = []

    let options: MatchOptions
    var onMatchFinished: ((MatchResult, [SetScore]) -> Void)?

    private var tieBreakInProgress: Bool = false
    private var cancellables = Set<AnyCancellable>()

    init(options: MatchOptions) {
        self.options = options
        score.noAdRule = options.noAdRule

        score.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func addPoint(_ side: PlayerSide) {
        guard score.addPoint(side) != nil else { return }
        withAnimation(.bouncy) {
            if side == .me { myGameScore += 1 } else { yourGameScore += 1 }
        }
        score.reset()
        checkSetUpdate()
    }

    func undo() {
        score.undo()
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

        // Tiebreak trigger at 6-6
        if !options.noTieRule && my == 6 && your == 6 {
            score.setTieBreakMode()
            tieBreakInProgress = true
            return
        }

        let maxG = max(my, your), minG = min(my, your)
        let setWinner: PlayerSide?

        if options.noTieRule {
            if my >= 6 && my > your { setWinner = .me }
            else if your >= 6 && your > my { setWinner = .opponent }
            else { setWinner = nil }
        } else {
            if maxG >= 6 && (maxG - minG) >= 2 { setWinner = my > your ? .me : .opponent }
            else { setWinner = nil }
        }

        if let winner = setWinner { finalizeSet(winner: winner) }
    }

    private func finalizeSet(winner: PlayerSide) {
        completedSets.append(SetScore(my: myGameScore, your: yourGameScore))
        if winner == .me { mySetScore += 1 } else { yourSetScore += 1 }
        myGameScore = 0
        yourGameScore = 0

        let setsToWin = options.mode.setsToWin
        if mySetScore >= setsToWin { onMatchFinished?(.win, completedSets) }
        else if yourSetScore >= setsToWin { onMatchFinished?(.loss, completedSets) }
    }

    func triggerEarlyEnd() {
        onMatchFinished?(.draw, completedSets)
    }
}
