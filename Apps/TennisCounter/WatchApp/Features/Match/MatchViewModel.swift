import Combine
import SwiftUI

class MatchViewModel: ObservableObject {
    @Published var score = Score()
    @Published var myGameScore: Int = 0
    @Published var yourGameScore: Int = 0
    @Published var mySetScore: Int = 0
    @Published var yourSetScore: Int = 0
    @Published var completedSets: [(my: Int, your: Int)] = []
    @Published var isMatchOver: Bool = false
    @Published var didWin: Bool = false

    let healthKit = HealthKitService.shared
    private var cancellables = Set<AnyCancellable>()
    private let connectivity = WatchConnectivityService.shared

    init() {
        score.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        connectivity.$receivedScoreUpdate
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in self?.applyScoreUpdate(update) }
            .store(in: &cancellables)
    }

    func startMatch() {
        healthKit.startWorkout()
    }

    func addMyPoint() {
        score.addMyPoint()
        checkGameUpdate()
        sendScoreUpdate()
    }

    func addYourPoint() {
        score.addYourPoint()
        checkGameUpdate()
        sendScoreUpdate()
    }

    func undo() {
        score.undo()
        sendScoreUpdate()
    }

    func startNewMatch() {
        myGameScore = 0
        yourGameScore = 0
        mySetScore = 0
        yourSetScore = 0
        completedSets = []
        isMatchOver = false
        didWin = false
        score.resetData()
    }

    private func sendScoreUpdate() {
        let update = ScoreUpdate(
            myScore: score.myScore,
            yourScore: score.yourScore,
            myGameScore: myGameScore,
            yourGameScore: yourGameScore
        )
        connectivity.sendScoreUpdate(update)
    }

    private func applyScoreUpdate(_ update: ScoreUpdate) {
        score.myScore = update.myScore
        score.yourScore = update.yourScore
        score.myIndex = score.scoreArr.firstIndex(of: update.myScore) ?? 0
        score.yourIndex = score.scoreArr.firstIndex(of: update.yourScore) ?? 0
        myGameScore = update.myGameScore
        yourGameScore = update.yourGameScore
    }

    private func checkGameUpdate() {
        if score.myScore == 50 {
            withAnimation(.bouncy) { myGameScore += 1 }
            score.resetData()
            checkSetUpdate(myWon: true)
        } else if score.yourScore == 50 {
            withAnimation(.bouncy) { yourGameScore += 1 }
            score.resetData()
            checkSetUpdate(myWon: false)
        }
    }

    private func checkSetUpdate(myWon: Bool) {
        let maxGames = max(myGameScore, yourGameScore)
        let minGames = min(myGameScore, yourGameScore)
        guard maxGames >= 6 && (maxGames - minGames) >= 2 else { return }

        completedSets.append((my: myGameScore, your: yourGameScore))

        if myWon { mySetScore += 1 } else { yourSetScore += 1 }
        myGameScore = 0
        yourGameScore = 0

        if mySetScore >= 1 {
            didWin = true
            isMatchOver = true
            Task { await finishMatch() }
        } else if yourSetScore >= 1 {
            didWin = false
            isMatchOver = true
            Task { await finishMatch() }
        }
    }

    private func finishMatch() async {
        _ = await healthKit.stopWorkout()
    }
}
