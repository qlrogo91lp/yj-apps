//
//  Score.swift
//  TennisCounter
//
//  Created by 윤재 on 2023/05/24.
//

import Foundation

class Score: ObservableObject {
    @Published var myScore: Int = 0
    @Published var yourScore: Int = 0
    @Published var myIndex: Int = 0
    @Published var yourIndex: Int = 0

    func resetData() {
        myScore = 0
        yourScore = 0
        myIndex = 0
        yourIndex = 0
    }
}
