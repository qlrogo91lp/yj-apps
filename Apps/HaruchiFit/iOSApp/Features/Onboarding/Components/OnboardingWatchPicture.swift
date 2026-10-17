import SwiftUI

/// 2장 그림 — 워치 운동 중 화면 이미지 위에 왼쪽 위 모드 아이콘 강조 고리를 얹는다.
/// 고리 위치는 이미지 기준 비율이다. 이미지를 바꾸면 이 값만 맞춘다.
struct OnboardingWatchPicture: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    private let ringCenter = CGPoint(x: 0.2952, y: 0.2959)
    private let ringDiameter: CGFloat = 0.13

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Image("OnboardingWatch")
                    .resizable()
                    .scaledToFill()
                Circle()
                    .stroke(HaruchiPalette.text, lineWidth: 3)
                    .frame(width: geo.size.width * ringDiameter, height: geo.size.width * ringDiameter)
                    .scaleEffect(reduceMotion || !pulsing ? 1 : 1.18)
                    .opacity(reduceMotion || !pulsing ? 1 : 0.4)
                    .position(x: geo.size.width * ringCenter.x, y: geo.size.height * ringCenter.y)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { pulsing = true }
        }
        .accessibilityHidden(true)
    }
}
