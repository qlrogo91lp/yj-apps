import SwiftUI

struct LaunchScreenView: View {
    let onFinished: () -> Void
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Color(red: 0.6784, green: 1.0, blue: 0.2549)
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

                Text("Ralli")
                    .font(.system(size: 52, weight: .bold))
                    .italic()
                    .foregroundStyle(.green)

                Text("Tennis Counter")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
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
