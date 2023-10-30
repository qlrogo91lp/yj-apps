//
//  ScoreListView.swift
//  GolfCounter
//
//  Created by 윤재 on 10/30/23.
//

import SwiftUI

struct ScoreListView: View {
    @State var total: Int = 0
    @StateObject var hole1 = ScoreDetail(id: 1)
    @StateObject var hole2 = ScoreDetail(id: 2)
    @StateObject var hole3 = ScoreDetail(id: 3)
    @StateObject var hole4 = ScoreDetail(id: 4)
    @StateObject var hole5 = ScoreDetail(id: 5)
    @StateObject var hole6 = ScoreDetail(id: 6)
    @StateObject var hole7 = ScoreDetail(id: 7)
    @StateObject var hole8 = ScoreDetail(id: 8)
    @StateObject var hole9 = ScoreDetail(id: 9)
    @StateObject var hole10 = ScoreDetail(id: 10)
    @StateObject var hole11 = ScoreDetail(id: 11)
    @StateObject var hole12 = ScoreDetail(id: 12)
    @StateObject var hole13 = ScoreDetail(id: 13)
    @StateObject var hole14 = ScoreDetail(id: 14)
    @StateObject var hole15 = ScoreDetail(id: 15)
    @StateObject var hole16 = ScoreDetail(id: 16)
    @StateObject var hole17 = ScoreDetail(id: 17)
    @StateObject var hole18 = ScoreDetail(id: 18)
    
    var body: some View {
        let total: Int = hole1.score + hole2.score + hole3.score + hole4.score + hole5.score + hole6.score + hole7.score + hole8.score + hole9.score
                    + hole10.score + hole11.score + hole12.score + hole13.score + hole14.score + hole15.score + hole16.score + hole17.score + hole18.score
        
        NavigationStack {
            
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack {
                    Text("Total : \(total)")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    List {
                        NavigationLink(destination: ScoreSetupView(scoreDetail: hole1)) {
                            ScoreView(scoreDetail: hole1)
                        }
                        NavigationLink(destination: ScoreSetupView(scoreDetail: hole2)) {
                            ScoreView(scoreDetail: hole2)
                        }
                        NavigationLink(destination: ScoreSetupView(scoreDetail: hole3)) {
                            ScoreView(scoreDetail: hole3)
                        }
                        NavigationLink(destination: ScoreSetupView(scoreDetail: hole4)) {
                            ScoreView(scoreDetail: hole4)
                        }
                        NavigationLink(destination: ScoreSetupView(scoreDetail: hole5)) {
                            ScoreView(scoreDetail: hole5)
                        }
                        NavigationLink(destination: ScoreSetupView(scoreDetail: hole6)) {
                            ScoreView(scoreDetail: hole6)
                        }
                        NavigationLink(destination: ScoreSetupView(scoreDetail: hole7)) {
                            ScoreView(scoreDetail: hole7)
                        }
                        NavigationLink(destination: ScoreSetupView(scoreDetail: hole8)) {
                            ScoreView(scoreDetail: hole8)
                        }
                        NavigationLink(destination: ScoreSetupView(scoreDetail: hole9)) {
                            ScoreView(scoreDetail: hole9)
                        }
                        NavigationLink(destination: ScoreSetupView(scoreDetail: hole10)) {
                            ScoreView(scoreDetail: hole10)
                        }
                        NavigationLink(destination: ScoreSetupView(scoreDetail: hole11)) {
                            ScoreView(scoreDetail: hole11)
                        }
                        NavigationLink(destination: ScoreSetupView(scoreDetail: hole12)) {
                            ScoreView(scoreDetail: hole12)
                        }
                        NavigationLink(destination: ScoreSetupView(scoreDetail: hole13)) {
                            ScoreView(scoreDetail: hole13)
                        }
                        NavigationLink(destination: ScoreSetupView(scoreDetail: hole14)) {
                            ScoreView(scoreDetail: hole14)
                        }
                        NavigationLink(destination: ScoreSetupView(scoreDetail: hole15)) {
                            ScoreView(scoreDetail: hole15)
                        }
                        NavigationLink(destination: ScoreSetupView(scoreDetail: hole16)) {
                            ScoreView(scoreDetail: hole16)
                        }
                        NavigationLink(destination: ScoreSetupView(scoreDetail: hole17)) {
                            ScoreView(scoreDetail: hole17)
                        }
                        NavigationLink(destination: ScoreSetupView(scoreDetail: hole18)) {
                            ScoreView(scoreDetail: hole18)
                        }
                    }.scrollContentBackground(.hidden)
                        .background(.black)
                }
            }
            
        }
    }
}

//#Preview {
//    ScoreListView()
//}
