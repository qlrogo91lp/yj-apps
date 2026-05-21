import SwiftUI

struct PlayerPointButton: View {
    let displayScore: String
    let player: String
    let color: Color
    let hasSetScore: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GeometryReader { geo in
                ZStack {
                    color.opacity(0.15)
                    VStack(spacing: 4) {
                        if geo.size.width > 81 && !hasSetScore {
                            Text(player)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(color)
                        }
                        Text(displayScore)
                            .font(.system(size: geo.size.width > 81 ? 46 : 40, weight: .bold))
                            .foregroundColor(color)
                            .contentTransition(.numericText())
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
