import SwiftUI

struct SetIndicatorView: View {
    let myGameScore: Int
    let yourGameScore: Int
    let isTieBreak: Bool
    let mySetScore: Int
    let yourSetScore: Int

    var body: some View {
        VStack(spacing: 4) {
            // Game score capsule
            HStack(spacing: 8) {
                Text("\(myGameScore)")
                    .foregroundColor(.green)
                    .contentTransition(.numericText())
                Text(isTieBreak ? String(localized: "set_tiebreak") : String(localized: "watch_set_label"))
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

            // Set score — show if any sets have been won
            if mySetScore > 0 || yourSetScore > 0 {
                HStack(spacing: 6) {
                    Text("\(mySetScore)")
                        .foregroundColor(.green.opacity(0.8))
                    Text("-")
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(yourSetScore)")
                        .foregroundColor(.orange.opacity(0.8))
                }
                .font(.system(size: 12, weight: .medium))
            }
        }
    }
}
