import SwiftData
import SwiftUI

@main
struct TennisCounterApp: App {
    let container: ModelContainer
    private let watchConnectivity = WatchConnectivityService.shared
    @State private var isLaunching = true

    init() {
        do {
            let schema = Schema([Match.self, SetRecord.self])
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            container = try ModelContainer(for: schema, configurations: config)
            let context = ModelContext(container)
            MatchPersistenceService.shared.configure(with: context)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            if isLaunching {
                LaunchScreenView(onFinished: { isLaunching = false })
            } else {
                MainTabView()
            }
        }
        .modelContainer(container)
    }
}

struct MainTabView: View {
    @State private var isMatchActive = false
    @State private var selectedTab: Int = 0
    @State private var remoteSession: SessionStartMessage?
    private let connectivity = WatchConnectivityService.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                SummaryView()
                    .tabItem { Label(String(localized: "tab_summary"), systemImage: "chart.bar.fill") }
                    .tag(0)

                HomeView(onMatchStart: { withAnimation { isMatchActive = true } })
                    .tabItem { Label(String(localized: "tab_match"), systemImage: "sportscourt.fill") }
                    .tag(1)

                HistoryView()
                    .tabItem { Label(String(localized: "tab_history"), systemImage: "clock.fill") }
                    .tag(2)
            }

            if isMatchActive {
                NavigationStack {
                    WorkoutSessionView(
                        remoteSession: remoteSession,
                        onExit: {
                            selectedTab = 1
                            remoteSession = nil
                            withAnimation { isMatchActive = false }
                        }
                    )
                }
                .transition(.opacity)
            }
        }
        .onReceive(connectivity.$receivedSessionStart.compactMap { $0 }) { msg in
            guard !isMatchActive else { return }
            remoteSession = msg
            withAnimation { isMatchActive = true }
        }
    }
}
