import SwiftUI

struct PlayerPointZone: View {
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
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .foregroundColor(color)
                    // caller must wrap score state change in withAnimation for this to fire
                    .contentTransition(.numericText())
            }
        }
        .onTapGesture { onTap() }
        .onLongPressGesture(minimumDuration: 0.5) { onLongPress() }
        .accessibilityLabel("\(playerLabel): \(displayScore)")
        .accessibilityHint("탭으로 포인트 추가, 길게 눌러 점수 수정")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    HStack(spacing: 0) {
        PlayerPointZone(displayScore: "40", playerLabel: "나", color: .green, onTap: {}, onLongPress: {})
        PlayerPointZone(displayScore: "15", playerLabel: "상대", color: .orange, onTap: {}, onLongPress: {})
    }
    .ignoresSafeArea()
    .background(.black)
}
