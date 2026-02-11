//
//  MatchView.swift
//  TennisCounter Watch App
//
//  Created by 윤재 on 2023/05/24.
//

import SwiftUI

struct MatchView: View {

    @State var myGameScore: Int = 0
    @State var yourGameScore: Int = 0
    @State var isMatchOver: Bool = false
    @State var didWin: Bool = false
    @StateObject var score: Score = .init()

    var body: some View {
        if isMatchOver {
            // 경기 결과 화면
            VStack(spacing: 12) {
                Text(didWin ? "Victory!" : "Defeat")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(didWin ? .green : .orange)

                // 최종 게임 스코어
                HStack {
                    Text("\(myGameScore)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.green)

                    Text(":")
                        .font(.system(size: 26, weight: .bold))

                    Text("\(yourGameScore)")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.orange)
                }

                Button(action: {
                    myGameScore = 0
                    yourGameScore = 0
                    score.resetData()
                    isMatchOver = false
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("New Match")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding()
        } else {
            // 경기 진행 화면
            VStack(spacing: 0) {
                // 세트 스코어
                HStack {
                    Text("\(myGameScore)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.green)
                        .contentTransition(.numericText()) // 전광판 스타일 숫자 롤링 애니메이션

                    Text(":")
                        .font(.system(size: 18, weight: .bold))

                    Text("\(yourGameScore)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.orange)
                        .contentTransition(.numericText()) // 전광판 스타일 숫자 롤링 애니메이션
                }

                Spacer()

                // 포인트 스코어
                HStack {
                    if score.myScore == 50 {
                        Text("Win")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.yellow)
                    } else {
                        Text("\(score.myScore)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.green)
                    }

                    Text(":")
                        .font(.system(size: 28, weight: .bold))

                    if score.yourScore == 50 {
                        Text("Win")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.yellow)
                    } else {
                        Text("\(score.yourScore)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }

                Spacer()

                // 득점 / 실점 버튼
                HStack(spacing: 12) {
                    Button(action: {
                        score.addMyPoint()
                        checkGameUpdate()
                    }) {
                        Text("Win")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button(action: {
                        score.addYourPoint()
                        checkGameUpdate()
                    }) {
                        Text("Lose")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }

                // Undo 버튼
                Button(action: {
                    score.undo()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .imageScale(.small)
                        Text("Undo")
                            .font(.system(size: 13))
                    }
                }
                .buttonStyle(.borderless)
                .disabled(score.lastAction == .none)
                .opacity(score.lastAction == .none ? 0.4 : 1.0)
            }
            .frame(maxHeight: .infinity)
            .padding()
        }
    }

    private func checkGameUpdate() {
        if score.myScore == 50 {
            withAnimation(.bouncy) { // 바운스 애니메이션으로 게임 스코어 갱신
                myGameScore += 1
            }
            score.resetData()
            if myGameScore >= 6 {
                didWin = true
                isMatchOver = true
            }
        } else if score.yourScore == 50 {
            withAnimation(.bouncy) { // 바운스 애니메이션으로 게임 스코어 갱신
                yourGameScore += 1
            }
            score.resetData()
            if yourGameScore >= 6 {
                didWin = false
                isMatchOver = true
            }
        }
    }
}

struct MatchView_Previews: PreviewProvider {
    static var previews: some View {
        MatchView()
    }
}
