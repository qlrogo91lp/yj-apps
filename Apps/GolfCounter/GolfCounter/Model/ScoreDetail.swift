//
//  ScoreDetail.swift
//  GolfCounter
//
//  Created by 윤재 on 10/30/23.
//

import Foundation

class ScoreDetail: Identifiable, ObservableObject {
    @Published var id: Int
    @Published var maxHole: String
    @Published var score: Int
    
    init(id: Int) {
        self.id = id
        self.maxHole = "3"
        self.score = 0
    }
}
