//
//  ContentView.swift
//  TennisCounter Watch App
//
//  Created by 윤재 on 2023/05/24.
//

import SwiftUI

struct ContentView: View {

    @State var myGameScore: Int = 0
    @State var yourGameScore: Int = 0
    @StateObject var score: Score = .init()

    var body: some View {
        VStack {
            HStack {
                Text("Score")
                    .padding(.trailing)
                Text("\(myGameScore)")
                    .foregroundColor(.green)

                Text(" : ")

                Text("\(yourGameScore)")
                    .foregroundColor(.orange)

                Button(action: {
                    myGameScore = 0
                    yourGameScore = 0
                    score.resetData()
                }, label: {
                    Text("Reset")
                        .foregroundColor(.blue)
                }).buttonStyle(.borderless).padding(.leading)
            }.padding(.top)

            HStack {
                CounterButtonView(flag: 0, score: score)

                Spacer()

                Text(":")
                    .font(.system(size: 25))

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
                    .foregroundColor(.blue)
            })
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(score: Score())
    }
}
