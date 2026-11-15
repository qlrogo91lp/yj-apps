import SwiftUI

/// 온보딩 ② 폰과 워치. 두 미니 화면이 같은 `5 / 8잔` 을 보인다.
struct BothDevicesPage: View {
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            HStack(alignment: .bottom, spacing: 20) {
                MiniScreen(width: 120, height: 220, cornerRadius: 26)
                MiniScreen(width: 96, height: 116, cornerRadius: 30)
            }
            VStack(spacing: 10) {
                Text("폰에서도, 워치에서도")
                    .font(.system(size: 28, weight: .bold))
                Text("어느 쪽에서 눌러도 같이 올라가요.")
                    .font(.system(size: 17))
                Text("워치가 없어도 폰만으로 쓸 수 있어요.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

/// 기기 모양 틀 안의 `5 / 8잔` + 막대. 그림이라 누를 수 없다.
private struct MiniScreen: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("5")
                    .font(.system(size: 30, weight: .bold).monospacedDigit())
                    .foregroundStyle(BrandColor.amber)
                Text("/ 8잔")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule().fill(BrandColor.amber).frame(width: proxy.size.width * 5 / 8)
                }
            }
            .frame(height: 5)
            .padding(.horizontal, 14)
        }
        .frame(width: width, height: height)
        .background(BrandColor.surface, in: RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(Color.white.opacity(0.25), lineWidth: 3))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("5 / 8잔")
    }
}

#Preview {
    BothDevicesPage()
        .background(BrandColor.background)
        .preferredColorScheme(.dark)
}
