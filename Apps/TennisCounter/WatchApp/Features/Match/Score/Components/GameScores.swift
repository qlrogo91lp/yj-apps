import SwiftUI

struct GameScores: View {
    let myGameScore: Int
    let yourGameScore: Int
    let isTieBreak: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("\(myGameScore)")
                .foregroundColor(.green)
                .contentTransition(.numericText())
            Text(isTieBreak ? String(localized: "set_tiebreak") : ":")
                .foregroundColor(.white)
            Text("\(yourGameScore)")
                .foregroundColor(.orange)
                .contentTransition(.numericText())
        }
        .font(.system(size: 15, weight: .bold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.8))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
    }
}

#Preview {
    GameScores(myGameScore: 1, yourGameScore: 0, isTieBreak: true)
}
