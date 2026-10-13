import SwiftUI

/// 3장 그림 — 건강 앱의 하트에서 잔디 칸으로 이어지는 정적 그림.
struct OnboardingHealthPicture: View {
    private let levels: [GrassLevel] = [.light, .medium, .heavy, .peak]

    var body: some View {
        VStack(spacing: 28) {
            Image(systemName: "heart.fill")
                .font(.system(size: 84))
                .foregroundStyle(HaruchiPalette.hr)
            Image(systemName: "arrow.down")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(HaruchiPalette.faint)
            HStack(spacing: 8) {
                ForEach(levels, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(HaruchiPalette.grass(level))
                        .frame(width: 44, height: 44)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HaruchiPalette.surface)
        .accessibilityHidden(true)
    }
}
