import SwiftUI

struct WorkoutIndicator: View {
    let elapsedFormatted: String

    @State private var rotation: Double = 0

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.brand)
                    .frame(width: 24, height: 24)
                Image("RalliIcon")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.black)
                    .frame(width: 20, height: 20)
            }
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }

            Text(elapsedFormatted)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.yellow)
        }
    }
}

#Preview {
    WorkoutIndicator(elapsedFormatted: "23:45")
        .preferredColorScheme(.dark)
}
