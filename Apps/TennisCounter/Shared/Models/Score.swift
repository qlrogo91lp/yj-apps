//
//  Score.swift
//  TennisCounter
//
//  Created by 윤재 on 2023/05/24.
//

import Foundation

enum LastAction {
    case myPoint
    case yourPoint
    case none
}

class Score: ObservableObject {
    @Published var myScore: Int = 0
    @Published var yourScore: Int = 0
    @Published var myIndex: Int = 0
    @Published var yourIndex: Int = 0
    @Published var lastAction: LastAction = .none

    let scoreArr = [0, 15, 30, 40, 50]

    func addMyPoint() {
        if myIndex < 4 {
            myIndex += 1
            myScore = scoreArr[myIndex]
            lastAction = .myPoint
        }
    }

    func addYourPoint() {
        if yourIndex < 4 {
            yourIndex += 1
            yourScore = scoreArr[yourIndex]
            lastAction = .yourPoint
        }
    }

    func undo() {
        switch lastAction {
        case .myPoint:
            if myIndex > 0 {
                myIndex -= 1
                myScore = scoreArr[myIndex]
            }
        case .yourPoint:
            if yourIndex > 0 {
                yourIndex -= 1
                yourScore = scoreArr[yourIndex]
            }
        case .none:
            break
        }
        lastAction = .none
    }

    func resetData() {
        myScore = 0
        yourScore = 0
        myIndex = 0
        yourIndex = 0
        lastAction = .none
    }
}
