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

    private var cancellable: AnyCancellable?

    init() {
        cancellable = score.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func addMyPoint() {
        score.addMyPoint()
        checkGameUpdate()
    }

    func addYourPoint() {
        score.addYourPoint()
        checkGameUpdate()
    }

    func undo() {
        score.undo()
    }

    func startNewMatch() {
        myGameScore = 0
        yourGameScore = 0
        score.resetData()
        isMatchOver = false
    }

    private func checkGameUpdate() {
        if score.myScore == 50 {
            withAnimation(.bouncy) {
                myGameScore += 1
            }
            score.resetData()
            if myGameScore >= 6 {
                didWin = true
                isMatchOver = true
            }
        } else if score.yourScore == 50 {
            withAnimation(.bouncy) {
                yourGameScore += 1
            }
            score.resetData()
            if yourGameScore >= 6 {
                didWin = false
                isMatchOver = true
            }
        }
    }
}
