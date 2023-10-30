//
//  ScoreSetupView.swift
//  GolfCounter Watch App
//
//  Created by 윤재 on 10/30/23.
//

import SwiftUI

struct ScoreSetupView: View {
    @StateObject var scoreDetail: ScoreDetail
    
    
    var body: some View {
        var select: Int = 3
        
        VStack {
            HStack {
                Text("Par \(scoreDetail.maxHole)")
                    .font(.system(size: 30))
                    .bold()
                    .foregroundColor(.blue)
                    .padding(.trailing)
                
                Text("+ \(scoreDetail.score)")
                    .font(.system(size: 30))
                    .bold()
                    .foregroundColor(.white)
                    .padding(.leading)
                
            }
            .padding(.bottom)
            
            
            HStack {
                Button(action: {
                    if(scoreDetail.score < (Int(scoreDetail.maxHole)!)*2) {
                        scoreDetail.score += 1
                    }
                }, label: {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 60, height: 60)
                        .overlay() {
                            Circle().stroke(.gray, lineWidth: 4)
                        }
                        .overlay() {
                            Image(systemName: "plus")
                                .imageScale(.large)
                                .bold()
                                .foregroundColor(.gray)
                        }
                }).buttonStyle(PlainButtonStyle())
                    .padding(.trailing)
                
                
                Button(action: {
                    if(scoreDetail.score > 0) {
                        scoreDetail.score -= 1
                    }
                }, label: {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 60, height: 60)
                        .overlay() {
                            Circle().stroke(.gray, lineWidth: 4)
                        }
                        .overlay() {
                            Image(systemName: "minus")
                                .imageScale(.large)
                                .bold()
                                .foregroundColor(.gray)
                        }
                }).buttonStyle(PlainButtonStyle())
                    .padding(.leading)
                
            }
            .padding(.bottom)
            .padding(.horizontal)
            
            HStack {
                Button(action: {
                    select = Int(scoreDetail.maxHole)!
                    
                    if (select == 5) {
                        select = 3
                        scoreDetail.maxHole = "3"
                    } else {
                        select += 1
                        scoreDetail.maxHole = "\(select)"
                    }
                }, label: {
                    Text("Type")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                        .bold()
                })
                
                
                Button(action: {
                    scoreDetail.score = 0
                }, label: {
                    Text("Reset")
                        .font(.system(size: 20))
                        .bold()
                        .foregroundColor(.gray)
                })
            }
        }
    }
}

#Preview {
    ScoreSetupView(scoreDetail: ScoreDetail(id: 10))
}
