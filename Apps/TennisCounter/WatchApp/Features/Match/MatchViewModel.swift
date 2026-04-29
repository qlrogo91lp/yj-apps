//
//  MatchViewModel.swift
//  TennisCounter Watch App
//
//  Created by 윤재 on 2023/05/24.
//

import Combine
import SwiftUI

class MatchViewModel: ObservableObject {
    @Published var score = Score()
    @Published var myGameScore: Int = 0
    @Published var yourGameScore: Int = 0
    @Published var isMatchOver: Bool = false
    @Published var didWin: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private let connectivity = WatchConnectivityService.shared

    init() {
        score.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        connectivity.$receivedScoreUpdate
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                self?.applyScoreUpdate(update)
            }
            .store(in: &cancellables)
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
        score.resetData()
        isMatchOver = false
        didWin = false
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
            if myGameScore >= 6 { didWin = true; isMatchOver = true }
        } else if score.yourScore == 50 {
            withAnimation(.bouncy) { yourGameScore += 1 }
            score.resetData()
            if yourGameScore >= 6 { didWin = false; isMatchOver = true }
        }
    }
}
