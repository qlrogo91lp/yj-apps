import PersistenceCore
import SwiftData
import SwiftUI

@main
struct TennisCounterApp: App {
    let container: ModelContainer
    private let watchConnectivity = MatchConnectivity.shared
    /// 경기 화면과 무관하게 세션 레코드를 저장한다. 앱 수명 내내 잡고 있어야 경기 없는
    /// 워크아웃의 기록을 놓치지 않는다 — WorkoutSessionRecorder 주석을 본다.
    private let sessionRecorder: WorkoutSessionRecorder
    @State private var isLaunching = true
    /// 마지막으로 본 온보딩 버전. 0 = 본 적 없음. 규칙은 OnboardingGate.
    @AppStorage("onboardingSeenVersion") private var onboardingSeenVersion = 0

    init() {
        // CloudKit 동기화 시도 → iCloud 미로그인·시뮬레이터 등 실패 시 로컬 폴백 (팩토리가 처리)
        container = PersistenceContainerFactory.make(
            for: [Match.self, SetRecord.self, WorkoutSessionRecord.self]
        )
        MatchPersistenceService.shared.configure(with: ModelContext(container))
        SessionPersistenceService.shared.configure(with: ModelContext(container))
        sessionRecorder = WorkoutSessionRecorder()
        Task { @MainActor in LiveActivityService.shared.endAll() }
    }

    var body: some Scene {
        WindowGroup {
            if isLaunching {
                LaunchScreenView(onFinished: { isLaunching = false })
            } else if OnboardingGate.shouldShow(seenVersion: onboardingSeenVersion) {
                OnboardingView(onFinished: {
                    withAnimation { onboardingSeenVersion = OnboardingGate.version }
                })
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
    @State private var historyActivationID = 0
    @State private var showHistoryList = false
    @State private var remoteSession: SessionStartMessage?
    private let connectivity = MatchConnectivity.shared

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: Binding(get: { selectedTab }, set: { selectTab($0) })) {
                SummaryView(onShowHistory: { selectTab(2, showList: true) })
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

                HistoryView(activationID: historyActivationID, showListOnActivation: showHistoryList)
                    .tabItem { Label(String(localized: "tab_history"), systemImage: "clock.fill") }
                    .tag(2)
            }
            // .colorScheme 은 SwiftUI 하위 트리만 바꾼다 — 시트 그래버·알림창·키보드는
            // 시스템 스타일을 따라가므로 앱 전체 고정은 .preferredColorScheme 으로 한다
            .preferredColorScheme(.dark)

            if isMatchActive {
                NavigationStack {
                    WorkoutSessionView(
                        remoteSession: remoteSession,
                        onExit: {
                            selectTab(1)
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

    private func selectTab(_ tab: Int, showList: Bool = false) {
        if tab == 2, selectedTab != tab {
            showHistoryList = showList
            historyActivationID += 1
        }
        selectedTab = tab
    }
}
