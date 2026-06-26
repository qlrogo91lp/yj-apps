import SwiftData
import SwiftUI

@main
struct TennisCounterApp: App {
    let container: ModelContainer
    private let watchConnectivity = WatchConnectivityService.shared
    @State private var isLaunching = true

    init() {
        let schema = Schema([Match.self, SetRecord.self])
        do {
            // iCloud 로그인 상태일 때 CloudKit 동기화 활성화
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // iCloud 미로그인(시뮬레이터, 개발 환경 등) 시 로컬 저장소로 폴백
            let config = ModelConfiguration(schema: schema)
            do {
                container = try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
        let context = ModelContext(container)
        MatchPersistenceService.shared.configure(with: context)
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
