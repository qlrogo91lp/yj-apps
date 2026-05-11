import SwiftUI

struct WorkoutMetricsView: View {
    @ObservedObject var healthKit: HealthKitService
    let isPaused: Bool
    @State private var heartScale: CGFloat = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(healthKit.formattedElapsed())
                .font(.system(size: 45, weight: .bold, design: .rounded))
                .foregroundColor(isPaused ? Color.yellow.opacity(0.5) : .yellow)
                .contentTransition(.numericText())

            HStack(alignment: .bottom, spacing: 6) {
                Text(String(format: "%.0f", healthKit.currentCalories))
                    .font(.system(size: 35, weight: .bold, design: .rounded))
                Text("kcal")
                    .font(.system(size: 20, weight: .semibold))
                    .padding(.bottom, 5)
            }

            HStack(alignment: .bottom, spacing: 6) {
                Text(heartRateText)
                    .font(.system(size: 35, weight: .bold, design: .rounded))
                Image(systemName: healthKit.currentHeartRate > 0 ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.red)
                    .scaleEffect(heartScale)
                    .onAppear {
                        if healthKit.currentHeartRate > 0 {
                            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                                heartScale = 1.2
                            }
                        }
                    }
                    .padding(.bottom, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 10)
        .background(Color.black.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Color.clear.frame(width: 36, height: 36)
            }
        }
    }

    private var heartRateText: String {
        healthKit.currentHeartRate > 0
            ? String(format: "%.0f", healthKit.currentHeartRate)
            : "--"
    }
}

#Preview("Active") {
    let service = HealthKitService.shared
    service.elapsedSeconds = 1523
    service.currentCalories = 245
    service.currentHeartRate = 102
    return WorkoutMetricsView(healthKit: service, isPaused: false)
}
