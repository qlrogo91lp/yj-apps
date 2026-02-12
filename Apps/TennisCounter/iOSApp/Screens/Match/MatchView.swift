//
//  MatchView.swift
//  TennisCounter
//
//  Created by 윤재 on 2023/05/24.
//

import SwiftUI

struct MatchView: View {

    @StateObject var viewModel = MatchViewModel()

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

                    Text("\(viewModel.myGameScore)")
                        .font(.system(size: 50))
                        .bold()
                        .foregroundColor(.green)

                    Text(" : ")
                        .font(.system(size: 30))
                        .bold()
                        .foregroundColor(.white)

                    Text("\(viewModel.yourGameScore)")
                        .font(.system(size: 50))
                        .bold()
                        .foregroundColor(.orange)

                    Spacer()

                    Button(action: {
                        viewModel.resetAll()
                    }, label: {
                        Text("Reset")
                            .font(.system(size: 30))
                            .bold()
                            .foregroundColor(.blue)
                    }).buttonStyle(.borderless).padding(.leading)
                }

                HStack {
                    CounterButtonView(flag: 0, score: viewModel.score)

                    Spacer()

                    Text(" : ")
                        .font(.system(size: 25))
                        .bold()
                        .foregroundColor(.white)

                    Spacer()

                    CounterButtonView(flag: 1, score: viewModel.score)
                }.padding(.vertical)

                Button(action: {
                    viewModel.confirmScore()
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

struct MatchView_Previews: PreviewProvider {
    static var previews: some View {
        MatchView()
    }
}
