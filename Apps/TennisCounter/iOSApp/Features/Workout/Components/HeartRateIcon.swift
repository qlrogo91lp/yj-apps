import SwiftUI

struct HeartRateIcon: View {
    let heartRate: Double

    @State private var scale: CGFloat = 1.0

    var body: some View {
        Image(systemName: heartRate > 0 ? "heart.fill" : "heart")
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
