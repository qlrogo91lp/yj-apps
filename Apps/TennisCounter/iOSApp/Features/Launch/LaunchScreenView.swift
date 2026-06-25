import SwiftUI

struct LaunchScreenView: View {
    let onFinished: () -> Void
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Color.brand
                .ignoresSafeArea()

            VStack {
                Group {
                    Image("RalliIcon")
                        .resizable()
                        .scaledToFit()
                }
                .frame(width: 60, height: 60)
                .rotationEffect(.degrees(rotation), anchor: .center)
                .clipped()
                .animation(.linear(duration: 1)
                    .repeatForever(autoreverses: false), value: rotation)

                BrandTitle(fontWeight: .bold)
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
