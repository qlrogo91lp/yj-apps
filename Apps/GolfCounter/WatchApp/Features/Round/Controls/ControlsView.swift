import SwiftUI
import WatchKit
import WorkoutCore

struct ControlsView: View {
    @ObservedObject var healthKit: WorkoutSessionService
    let onEndRound: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button {
                if healthKit.isPaused {
                    healthKit.resumeWorkout()
                } else {
                    healthKit.pauseWorkout()
                }
            } label: {
                Label(healthKit.isPaused ? "재개" : "일시정지",
                      systemImage: healthKit.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.plain)
            .background(Color.yellow.opacity(0.8), in: Capsule())
            .foregroundStyle(.black)

            Button(action: onEndRound) {
                Label("라운드 종료", systemImage: "flag.checkered")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.plain)
            .background(Color.red.opacity(0.8), in: Capsule())
            .foregroundStyle(.white)

            Button {
                WKInterfaceDevice.current().enableWaterLock()
            } label: {
                Label("잠금", systemImage: "drop.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.plain)
            .background(Color.blue.opacity(0.7), in: Capsule())
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 6)
    }
}
