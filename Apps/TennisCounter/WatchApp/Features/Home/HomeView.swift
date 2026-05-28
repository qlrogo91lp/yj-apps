import SwiftUI

struct HomeView: View {
    @State private var navigateToWorkout = false
    @State private var remoteSession: SessionStartMessage?
    private let connectivity = WatchConnectivityService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                VStack(spacing: 4) {
                    Text("Ralli")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.green)
                        .italic()
                    Text("Tennis Counter")
                        .font(.system(size: 14, weight: .semibold))
                }
                Button {
                    guard !navigateToWorkout else { return }
                    connectivity.receivedSessionStart = nil
                    connectivity.receivedWorkoutEnd = nil
                    connectivity.receivedMatchEnd = nil
                    navigateToWorkout = true
                } label: {
                    Text(String(localized: "watch_start_workout"))
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Spacer()
            }
            .padding()
            .navigationDestination(isPresented: $navigateToWorkout) {
                WorkoutSessionView(remoteSession: remoteSession)
            }
        }
        .onReceive(connectivity.$receivedSessionStart.compactMap { $0 }) { msg in
            guard !navigateToWorkout else { return }
            remoteSession = msg
            connectivity.receivedSessionStart = nil
            connectivity.receivedWorkoutEnd = nil
            connectivity.receivedMatchEnd = nil
            navigateToWorkout = true
        }
    }
}

#Preview {
    HomeView()
}
