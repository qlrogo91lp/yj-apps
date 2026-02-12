//
//  MatchViewModel.swift
//  TennisCounter
//
//  Created by 윤재 on 2023/05/24.
//

import SwiftUI

class MatchViewModel: ObservableObject {
    @Published var score = Score()
    @Published var myGameScore: Int = 0
    @Published var yourGameScore: Int = 0

    func confirmScore() {
        if score.myScore != score.yourScore {
            if score.myScore == 50 {
                if myGameScore < 6 {
                    myGameScore += 1
                }
                score.resetData()
            } else if score.yourScore == 50 {
                if yourGameScore < 6 {
                    yourGameScore += 1
                }
                score.resetData()
            }
        }
    }

    func resetAll() {
        myGameScore = 0
        yourGameScore = 0
        score.resetData()
    }
}
