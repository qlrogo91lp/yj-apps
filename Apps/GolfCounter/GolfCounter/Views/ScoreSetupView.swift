//
//  ScoreSetupView.swift
//  GolfCounter
//
//  Created by 윤재 on 10/30/23.
//

import SwiftUI

struct ScoreSetupView: View {
    @StateObject var scoreDetail: ScoreDetail
    
    
    var body: some View {
        var select: Int = 3
        
        
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Text("Par \(scoreDetail.maxHole)")
                        .font(.system(size: 35))
                        .bold()
                        .foregroundColor(.blue)
                        .padding(.trailing)
                    
                    Spacer()
                    
                    Text("+ \(scoreDetail.score)")
                        .font(.system(size: 35))
                        .bold()
                        .foregroundColor(.white)
                    
                }
                .padding()
                
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
                    })
                    
                    Spacer()
                    
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
                    })
                    
                }
                .padding()
                
                VStack {
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
                        Text("Hole Type")
                            .foregroundColor(.blue)
                            .bold()
                            .font(.system(size: 35))
                            
                    })
                    .padding(.bottom)
                    
                    
                    Button(action: {
                        scoreDetail.score = 0
                    }, label: {
                        Text("Reset")
                            .font(.system(size: 35))
                            .bold()
                            .foregroundColor(.gray)
                    })
                }
            }
            .padding(.maximum(80, 80))
        }
    }
}

#Preview {
    ScoreSetupView(scoreDetail: ScoreDetail(id: 10))
}
