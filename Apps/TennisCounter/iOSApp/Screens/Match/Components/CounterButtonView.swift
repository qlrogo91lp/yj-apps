//
//  CounterButtonView.swift
//  TennisCounter
//
//  Created by 윤재 on 2023/05/24.
//

import SwiftUI

struct CounterButtonView: View {
    var flag: Int
    var scoreArr = [0, 15, 30, 40, 50]
    @ObservedObject var score: Score

    var body: some View {

        HStack {
            // flag가 0이면 myScore, 1이면 yourScore
            if flag == 0 {

                VStack {
                    Button(action: {
                        if score.myIndex < 4 {
                            score.myIndex += 1
                            score.myScore = scoreArr[score.myIndex]
                        }
                    }, label: {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 70, height: 70)
                            .overlay {
                                Circle().stroke(.gray, lineWidth: 3)
                            }
                            .overlay {
                                Image(systemName: "plus")
                                    .imageScale(.large)
                                    .foregroundColor(.gray)
                            }
                    }).buttonStyle(.borderless)

                    Button(action: {
                        if score.myIndex > 0 {
                            score.myIndex -= 1
                            score.myScore = scoreArr[score.myIndex]
                        }
                    }, label: {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 70, height: 70)
                            .overlay {
                                Circle().stroke(.gray, lineWidth: 3)
                            }
                            .overlay {
                                Image(systemName: "minus")
                                    .imageScale(.large)
                                    .foregroundColor(.gray)
                            }
                    }).buttonStyle(.borderless)
                }

                Spacer()

                if score.myScore == 50 {
                    Text("Win")
                        .font(.system(size: 40))
                        .bold()
                        .foregroundColor(.yellow)
                } else {
                    Text("\(score.myScore)")
                        .font(.system(size: 50))
                        .bold()
                        .foregroundColor(.green)
                }

            } else {

                if score.yourScore == 50 {
                    Text("Win")
                        .font(.system(size: 40))
                        .bold()
                        .foregroundColor(.yellow)
                } else {
                    Text("\(score.yourScore)")
                        .font(.system(size: 50))
                        .bold()
                        .foregroundColor(.orange)
                }

                Spacer()

                VStack {
                    Button(action: {
                        if score.yourIndex < 4 {
                            score.yourIndex += 1
                            score.yourScore = scoreArr[score.yourIndex]
                        }
                    }, label: {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 70, height: 70)
                            .overlay {
                                Circle().stroke(.gray, lineWidth: 3)
                            }
                            .overlay {
                                Image(systemName: "plus")
                                    .imageScale(.large)
                                    .foregroundColor(.gray)
                            }
                    }).buttonStyle(.borderless)

                    Button(action: {
                        if score.yourIndex > 0 {
                            score.yourIndex -= 1
                            score.yourScore = scoreArr[score.yourIndex]
                        }
                    }, label: {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 70, height: 70)
                            .overlay {
                                Circle().stroke(.gray, lineWidth: 3)
                            }
                            .overlay {
                                Image(systemName: "minus")
                                    .imageScale(.large)
                                    .foregroundColor(.gray)
                            }
                    }).buttonStyle(.borderless)
                }
            }

        }
    }
}

struct CounterButtonView_Previews: PreviewProvider {
    static var previews: some View {
        CounterButtonView(flag: 0, score: Score())
    }
}
