import SwiftUI

/// 3장 그림 위에 얹는 컴플리케이션 강조 고리. 문자판 이미지의 GolfCounter 아이콘 자리에서 숨 쉬듯 커졌다 작아진다.
/// 위치는 이미지(4:5) 기준 비율이다. 이미지를 바꾸면 이 값만 맞춘다.
struct OnboardingComplicationRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    private let center = CGPoint(x: 0.3867, y: 0.36)
    private let diameter: CGFloat = 0.125

    var body: some View {
        GeometryReader { geo in
            Circle()
                .stroke(.white, lineWidth: 3)
                .frame(width: geo.size.width * diameter, height: geo.size.width * diameter)
                .scaleEffect(reduceMotion || !pulsing ? 1 : 1.18)
                .opacity(reduceMotion || !pulsing ? 1 : 0.4)
                .position(x: geo.size.width * center.x, y: geo.size.height * center.y)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { pulsing = true }
        }
        .accessibilityHidden(true)
    }
}
