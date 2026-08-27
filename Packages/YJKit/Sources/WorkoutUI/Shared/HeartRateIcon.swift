import SwiftUI

/// 심박이 잡히면 채워진 하트가 맥동하고, 0이면 빈 하트로 정지한다.
public struct HeartRateIcon: View {
    private let heartRate: Double
    private let size: CGFloat

    @State private var scale: CGFloat = 1.0

    public init(heartRate: Double, size: CGFloat = 20) {
        self.heartRate = heartRate
        self.size = size
    }

    public var body: some View {
        Image(systemName: heartRate > 0 ? "heart.fill" : "heart")
            .font(.system(size: size, weight: .semibold))
            .foregroundColor(.red)
            .scaleEffect(scale)
            .onAppear {
                guard heartRate > 0 else { return }
                startPulse()
            }
            .onChange(of: heartRate > 0) { _, isActive in
                if isActive {
                    startPulse()
                } else {
                    withAnimation(.default) { scale = 1.0 }
                }
            }
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            scale = 1.3
        }
    }
}
