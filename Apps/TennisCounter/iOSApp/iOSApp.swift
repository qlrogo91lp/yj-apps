import PersistenceCore
import SwiftData
import SwiftUI

@main
struct TennisCounterApp: App {
    let container: ModelContainer
    private let watchConnectivity = MatchConnectivity.shared
    @State private var isLaunching = true

    init() {
        // CloudKit 동기화 시도 → iCloud 미로그인·시뮬레이터 등 실패 시 로컬 폴백 (팩토리가 처리)
        container = PersistenceContainerFactory.make(for: [Match.self, SetRecord.self])
        MatchPersistenceService.shared.configure(with: ModelContext(container))
        Task { @MainActor in LiveActivityService.shared.endAll() }
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
    private let connectivity = MatchConnectivity.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                SummaryView()
                    .tabItem { Label(String(localized: "tab_summary"), systemImage: "chart.bar.fill") }
                    .tag(0)

                HomeView(onMatchStart: {
                    connectivity.receivedWorkoutEnd = nil
                    connectivity.receivedMatchEnd = nil
                    connectivity.receivedMatchSave = nil
                    connectivity.receivedMatchSaveResult = nil
                    withAnimation { isMatchActive = true }
                })
                .tabItem { Label(String(localized: "tab_match"), systemImage: "sportscourt.fill") }
                .tag(1)

                HistoryView()
                    .tabItem { Label(String(localized: "tab_history"), systemImage: "clock.fill") }
                    .tag(2)
            }
            .colorScheme(.dark)

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
        .onReceive(connectivity.$receivedSessionStart.compactMap(\.self)) { msg in
            guard !isMatchActive else { return }
            remoteSession = msg
            connectivity.receivedSessionStart = nil
            connectivity.receivedWorkoutEnd = nil
            connectivity.receivedMatchEnd = nil
            connectivity.receivedMatchSave = nil
            connectivity.receivedMatchSaveResult = nil
            withAnimation { isMatchActive = true }
        }
    }
}
