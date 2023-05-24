//
//  ContentView.swift
//  TennisCounter
//
//  Created by 윤재 on 2023/05/24.
//

import SwiftUI

struct ContentView: View {
    
    @State var myGameScore: Int = 0
    @State var yourGameScore: Int = 0
    @StateObject var score: Score = Score()
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Text("Score")
                        .font(.system(size: 30))
                        .bold()
                        .padding(.trailing)
                        .foregroundColor(.white)
                    
                    Text("\(myGameScore)")
                        .font(.system(size: 50))
                        .bold()
                        .foregroundColor(.green)
                    
                    Text(" : ")
                        .font(.system(size: 30))
                        .bold()
                        .foregroundColor(.white)
                    
                    Text("\(yourGameScore)")
                        .font(.system(size: 50))
                        .bold()
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Button(action: {
                        myGameScore = 0
                        yourGameScore = 0
                        score.resetData()
                    }, label: {
                        Text("Reset")
                            .font(.system(size: 30))
                            .bold()
                            .foregroundColor(.blue)
                    }).buttonStyle(.borderless).padding(.leading)
                }
                
                HStack {
                    CounterButtonView(flag: 0, score: score)
                    
                    Spacer()
                    
                    Text(" : ")
                        .font(.system(size: 25))
                        .bold()
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    CounterButtonView(flag: 1, score: score)
                }.padding(.vertical)
                
                Button(action: {

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
                    
                }, label: {
                    Text("Confirm")
                        .font(.system(size: 30))
                        .foregroundColor(.blue)
                        .bold()
                })
            }
            .padding()
        }
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(score: Score())
    }
}
