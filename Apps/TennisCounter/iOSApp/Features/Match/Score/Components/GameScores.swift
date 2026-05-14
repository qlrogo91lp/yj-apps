import SwiftUI

struct GameScores: View {
    let myGameScore: Int
    let yourGameScore: Int
    let isTieBreak: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("\(myGameScore)")
                .foregroundColor(.green)
                .contentTransition(.numericText())
            Text(isTieBreak ? String(localized: "set_tiebreak") : ":")
                .foregroundColor(.white)
            Text("\(yourGameScore)")
                .foregroundColor(.orange)
                .contentTransition(.numericText())
        }
        .font(.system(size: 20, weight: .bold))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.75))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
    }
}

#Preview {
    VStack(spacing: 12) {
        GameScores(myGameScore: 3, yourGameScore: 2, isTieBreak: false)
        GameScores(myGameScore: 6, yourGameScore: 6, isTieBreak: true)
    }
    .padding()
    .background(Color.black)
}
