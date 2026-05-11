import SwiftUI

struct PlayerScoreZone: View {
    let displayScore: String
    let playerLabel: String
    let color: Color
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        ZStack {
            color.opacity(0.15)
            VStack(spacing: 8) {
                Text(playerLabel)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                Text(displayScore)
                    .font(.system(size: 72, weight: .heavy))
                    .foregroundColor(color)
                    .contentTransition(.numericText())
            }
        }
        .onTapGesture { onTap() }
        .onLongPressGesture(minimumDuration: 0.5) { onLongPress() }
    }
}

#Preview {
    HStack(spacing: 0) {
        PlayerScoreZone(displayScore: "40", playerLabel: "나", color: .green, onTap: {}, onLongPress: {})
        PlayerScoreZone(displayScore: "15", playerLabel: "상대", color: .orange, onTap: {}, onLongPress: {})
    }
    .ignoresSafeArea()
    .background(.black)
}
