import Combine
import SwiftData
import SwiftUI

@MainActor
final class MatchViewModel: ObservableObject {
    let format: MatchFormat

    @Published var score = Score()
    @Published var myGameScore: Int = 0
    @Published var yourGameScore: Int = 0
    @Published var mySetScore: Int = 0
    @Published var yourSetScore: Int = 0
    @Published var currentSetNumber: Int = 1
    @Published var completedSets: [(my: Int, your: Int)] = []
    @Published var isMatchOver: Bool = false
    @Published var didWin: Bool = false

    private var cancellable: AnyCancellable?
    private var modelContext: ModelContext?
    private let connectivity = WatchConnectivityService.shared
    private let healthKit = HealthKitService.shared

    init(format: MatchFormat = .oneSet, modelContext: ModelContext? = nil) {
        self.format = format
        self.modelContext = modelContext
        cancellable = score.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func injectContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func requestHealthKitAndStart() async {
        await healthKit.requestAuthorization()
    }

    func confirmScore() {
        guard score.myScore != score.yourScore else { return }

        if score.myScore == 50 {
            myGameScore += 1
            score.resetData()
            sendScoreUpdate()
            checkSetUpdate()
        } else if score.yourScore == 50 {
            yourGameScore += 1
            score.resetData()
            sendScoreUpdate()
            checkSetUpdate()
        }
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
        score.resetData()
    }

    // MARK: - Private

    private func checkSetUpdate() {
        guard isSetComplete() else { return }

        let myWonSet = myGameScore > yourGameScore
        completedSets.append((my: myGameScore, your: yourGameScore))

        if myWonSet {
            mySetScore += 1
        } else {
            yourSetScore += 1
        }

        myGameScore = 0
        yourGameScore = 0
        currentSetNumber += 1

        if mySetScore >= format.setsToWin {
            didWin = true
            isMatchOver = true
            saveMatch()
        } else if yourSetScore >= format.setsToWin {
            didWin = false
            isMatchOver = true
            saveMatch()
        }
    }

    private func isSetComplete() -> Bool {
        let maxGames = max(myGameScore, yourGameScore)
        let minGames = min(myGameScore, yourGameScore)
        return maxGames >= 6 && (maxGames - minGames) >= 2
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

    private func saveMatch() {
        guard let context = modelContext else { return }

        let match = Match(matchFormat: format)
        match.endedAt = Date()
        match.myTotalSets = mySetScore
        match.yourTotalSets = yourSetScore
        match.isCompleted = true
        match.durationSeconds = healthKit.elapsedSeconds

        let setRecords = completedSets.enumerated().map { index, result in
            SetRecord(myGames: result.my, yourGames: result.your, setNumber: index + 1)
        }
        match.sets = setRecords
        context.insert(match)
        try? context.save()
    }
}
