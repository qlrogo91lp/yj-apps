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

    private var cancellable: AnyCancellable?
    private let connectivity = WatchConnectivityService.shared

    init(options: MatchOptions = MatchOptions(mode: .oneSet, noAdRule: true, noTieRule: false)) {
        self.options = options
        self.score.noAdRule = options.noAdRule
        cancellable = score.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func addPoint(_ side: PlayerSide) {
        guard !isMatchOver else { return }
        guard score.addPoint(side) != nil else { return }
        if side == .me { myGameScore += 1 } else { yourGameScore += 1 }
        score.resetData()
        sendScoreUpdate()
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

    private func sendScoreUpdate() {
        connectivity.sendScoreUpdate(ScoreUpdate(
            myScore: score.myScore,
            yourScore: score.yourScore,
            myGameScore: myGameScore,
            yourGameScore: yourGameScore
        ))
    }
}
