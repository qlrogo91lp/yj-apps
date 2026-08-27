import Combine
import SwiftUI

class ScoreViewModel: ObservableObject {
    @Published var score = Score()
    @Published var myGameScore: Int = 0
    @Published var yourGameScore: Int = 0
    @Published var mySetScore: Int = 0
    @Published var yourSetScore: Int = 0
    @Published var completedSets: [SetScore] = []

    @Published private(set) var options: MatchOptions
    var onMatchFinished: ((MatchResult, [SetScore]) -> Void)?

    /// 포인트 하나마다 쌓이는 경기 전체 상태. 게임·세트 경계를 넘어 되돌리기 위해
    /// Score뿐 아니라 게임·세트 스코어와 완료 세트까지 함께 봉인한다.
    private struct Snapshot {
        let score: Score.Snapshot
        let myGameScore: Int
        let yourGameScore: Int
        let mySetScore: Int
        let yourSetScore: Int
        let completedSets: [SetScore]
        let tieBreakInProgress: Bool
    }

    private var snapshots: [Snapshot] = []
    private var tieBreakInProgress: Bool = false
    private var cancellables = Set<AnyCancellable>()

    var onStateChanged: (() -> Void)?

    var canUndo: Bool {
        !snapshots.isEmpty
    }

    init(options: MatchOptions) {
        self.options = options
        score.noAdRule = options.noAdRule

        score.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func addPoint(_ side: PlayerSide) {
        snapshots.append(captureSnapshot())
        let gameWon = score.addPoint(side)
        if gameWon != nil {
            withAnimation(.bouncy) {
                if side == .me { myGameScore += 1 } else { yourGameScore += 1 }
            }
            score.reset()
            checkSetUpdate()
        }
        onStateChanged?()
    }

    /// 경기 시작까지 되돌린다 — 게임·세트 경계를 넘는다.
    func undo() {
        guard let snapshot = snapshots.popLast() else { return }
        apply(snapshot)
        onStateChanged?()
    }

    func makeScoreState() -> ScoreState {
        let myScore = score.gameMode == .tieBreak ? score.myTieBreak : score.myScore
        let yourScore = score.gameMode == .tieBreak ? score.yourTieBreak : score.yourScore
        return ScoreState(
            myScore: myScore, yourScore: yourScore,
            myGameScore: myGameScore, yourGameScore: yourGameScore,
            mySetScore: mySetScore, yourSetScore: yourSetScore,
            completedSets: completedSets.map { [$0.my, $0.your] },
            isTieBreak: score.gameMode == .tieBreak
        )
    }

    func resetAll(options: MatchOptions) {
        self.options = options
        myGameScore = 0
        yourGameScore = 0
        mySetScore = 0
        yourSetScore = 0
        completedSets = []
        tieBreakInProgress = false
        snapshots.removeAll()
        score.noAdRule = options.noAdRule
        score.reset()
    }

    func applyRemoteState(_ state: ScoreState) {
        myGameScore = state.myGameScore
        yourGameScore = state.yourGameScore
        mySetScore = state.mySetScore
        yourSetScore = state.yourSetScore
        completedSets = state.completedSets.map { SetScore(my: $0[0], your: $0[1]) }
        score.applyRemote(myScore: state.myScore, yourScore: state.yourScore, isTieBreak: state.isTieBreak)
        tieBreakInProgress = state.isTieBreak
        // mirror 측은 스스로 되돌릴 수 없다 — 권한은 driver에 있다.
        snapshots.removeAll()
    }

    private func captureSnapshot() -> Snapshot {
        Snapshot(
            score: score.makeSnapshot(),
            myGameScore: myGameScore,
            yourGameScore: yourGameScore,
            mySetScore: mySetScore,
            yourSetScore: yourSetScore,
            completedSets: completedSets,
            tieBreakInProgress: tieBreakInProgress
        )
    }

    private func apply(_ snapshot: Snapshot) {
        score.restore(snapshot.score)
        myGameScore = snapshot.myGameScore
        yourGameScore = snapshot.yourGameScore
        mySetScore = snapshot.mySetScore
        yourSetScore = snapshot.yourSetScore
        completedSets = snapshot.completedSets
        tieBreakInProgress = snapshot.tieBreakInProgress
    }

    private func checkSetUpdate() {
        let threshold = options.gameThreshold
        let my = myGameScore, your = yourGameScore

        if tieBreakInProgress {
            if (my == threshold + 1 && your == threshold) || (your == threshold + 1 && my == threshold) {
                tieBreakInProgress = false
                let winner: PlayerSide = my == threshold + 1 ? .me : .opponent
                finalizeSet(winner: winner)
            }
            return
        }

        if my == threshold, your == threshold {
            if options.noTieRule {
                completedSets.append(SetScore(my: my, your: your))
                onMatchFinished?(.draw, completedSets)
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
