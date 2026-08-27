import SwiftUI

/// 앱 진입 시 1.5초간 보여 주는 랜딩 화면 — Ralli(tennis_counter)의 LaunchScreenView와 같은 구성이다.
struct LaunchScreenView: View {
    let onFinished: () -> Void

    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Color.brand
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image("GolfIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(rotation), anchor: .center)
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: rotation)

                Text(verbatim: "GolfCounter")
                    .font(.system(size: 36, weight: .bold))
                    .italic()
                    .foregroundStyle(Color.brandForeground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .task {
            rotation = 360
            try? await Task.sleep(for: .seconds(1.5))
            onFinished()
        }
    }
}

#Preview {
    LaunchScreenView(onFinished: {})
}
