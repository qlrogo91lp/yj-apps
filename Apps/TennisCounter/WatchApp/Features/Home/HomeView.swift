import SwiftUI

struct HomeView: View {
    @State private var autoNavigate = false
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
                NavigationLink(destination: WorkoutSessionView()) {
                    Text(String(localized: "watch_start_workout"))
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Spacer()
            }
            .padding()
            .navigationDestination(isPresented: $autoNavigate) {
                WorkoutSessionView(remoteSession: remoteSession)
            }
        }
        .onReceive(connectivity.$receivedSessionStart.compactMap { $0 }) { msg in
            remoteSession = msg
            autoNavigate = true
        }
    }
}

#Preview {
    HomeView()
}
