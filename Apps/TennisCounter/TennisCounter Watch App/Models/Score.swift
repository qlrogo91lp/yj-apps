//
//  Score.swift
//  TennisCounter Watch App
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
        self.myScore = 0
        self.yourScore = 0
        self.myIndex = 0
        self.yourIndex = 0
    }
}
