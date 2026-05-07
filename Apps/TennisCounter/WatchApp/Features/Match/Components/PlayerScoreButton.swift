import SwiftUI

struct PlayerScoreButton: View {
    let displayScore: String
    let player: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                color.opacity(0.15)
                VStack(spacing: 4) {
                    Text(player)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(color)
                    Text(displayScore)
                        .font(.system(size: 46, weight: .bold))
                        .foregroundColor(color)
                        .contentTransition(.numericText())
                }
            }
        }
        .buttonStyle(.plain)
    }
}
