//
//  ScoreView.swift
//  GolfCounter
//
//  Created by 윤재 on 2023/05/08.
//

import SwiftUI

struct ScoreView: View {
    @StateObject var scoreDetail: ScoreDetail
    
    var body: some View {
        
        HStack {
            Circle()
                .fill(Color.white)
                .frame(width: 30, height: 30)
                .overlay() {
                    Circle().stroke(.gray, lineWidth: 4)
                }
                .overlay() {
                    Text("\(scoreDetail.id)")
                        .foregroundColor(.black)
                }
                .padding(.trailing)

            VStack {
                HStack {
                    Text("Par\(scoreDetail.maxHole)")
                        .foregroundColor(.blue)

                    Spacer()
                    
                    let result = scoreDetail.score - Int(scoreDetail.maxHole)!
                    
                    if scoreDetail.score == 0 {
                        Text("-")
                            .bold()
                            .foregroundColor(.green)
                    } else {
                        if result > 0 {
                            Text("+ \(result)")
                                .bold()
                                .foregroundColor(.red)
                        } else {
                            Text("\(result)")
                                .bold()
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                    
                    if scoreDetail.score == 0 {
                        Text("-")
                            .bold()
                            .foregroundColor(.black)
                    } else {
                        Text("+ \(scoreDetail.score)")
                            .bold()
                            .foregroundColor(.black)
                    }
                }
            }
        }
    }
}

//#Preview {
//    ScoreView(scoreDetail: ScoreDetail(id: 10))
//}
