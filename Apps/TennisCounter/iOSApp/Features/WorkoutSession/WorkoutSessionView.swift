import SwiftUI
import WorkoutUI

struct WorkoutSessionView: View {
    let onExit: () -> Void
    let remoteSession: SessionStartMessage?

    @StateObject private var viewModel = WorkoutSessionViewModel()
    @State private var selectedTab: Int = 1
    @State private var showEndMatchConfirm = false
    @State private var showEndWorkoutConfirm = false
    @State private var hasMatchProgress = false

    init(remoteSession: SessionStartMessage? = nil, onExit: @escaping () -> Void) {
        self.remoteSession = remoteSession
        self.onExit = onExit
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            WorkoutDashboardView(
                metrics: viewModel.metrics,
                isPaused: viewModel.isPaused,
                isPauseAvailable: viewModel.isPauseAvailable,
                onPauseResume: {
                    viewModel.isPaused ? viewModel.requestResume() : viewModel.requestPause()
                },
                onEnd: { showEndWorkoutConfirm = true }
            )
            .tabItem { Label(String(localized: "tab_workout"), systemImage: "figure.run") }
            .tag(0)

            scoreTabContent
                .tabItem { Label(String(localized: "tab_match"), systemImage: "sportscourt.fill") }
                .tag(1)
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
        // 툴바는 개별 탭이 아니라 TabView에 걸려 두 탭이 공유한다. 매치 탭 전용 아이템이
        // 워크아웃 탭에 새어나가지 않도록, 필요 없는 상황에서는 아이템 자체를 올리지 않는다.
        // (빈 뷰로 자리만 채우면 iOS 26 툴바가 내용 없는 유리 배경만 덩그러니 그린다.)
        .toolbar {
            if let backAction = matchBackAction {
                ToolbarItem(placement: .topBarLeading) {
                    BackButton(action: backAction)
                }
            }
            ToolbarItem(placement: .principal) {
                matchTitle
                    .frame(height: Self.toolbarTitleHeight)
            }
        }
        .alert(
            String(localized: "early_end_confirm_title"),
            isPresented: $showEndMatchConfirm
        ) {
            Button(String(localized: "early_end_confirm_yes"), role: .destructive) {
                hasMatchProgress = false
                viewModel.startNewMatch()
            }
            Button(String(localized: "btn_cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "early_end_confirm_message"))
        }
        .alert(
            String(localized: "end_workout_confirm_title"),
            isPresented: $showEndWorkoutConfirm
        ) {
            Button(String(localized: "workout_end"), role: .destructive) {
                viewModel.endSession()
                onExit()
            }
            Button(String(localized: "btn_cancel"), role: .cancel) {}
        } message: {
            if case .playing = viewModel.phase {
                Text(String(localized: "end_workout_with_match_message"))
            } else {
                Text(String(localized: "end_workout_confirm_message"))
            }
        }
        .onAppear {
            if let remote = remoteSession {
                viewModel.startSession(startDate: remote.workoutStartDate)
                viewModel.startMatch(options: remote.options, sessionId: remote.sessionId, matchId: remote.matchId, isRemote: true)
            } else {
                viewModel.startSession()
            }
        }
        .onChange(of: viewModel.remoteWorkoutEnded) {
            if viewModel.remoteWorkoutEnded { onExit() }
        }
    }

    /// 매치 탭 전용 뒤로가기 동작 — phase별로 다르다. `nil`이면 툴바에 버튼을 올리지 않는다.
    /// `.playing`에서 진행 중인 매치를 끝낼 권한은 driver에게만 있다 (점수 입력·undo와 같은 규칙).
    /// mirror에게는 눌러도 아무 일 없는 버튼을 보여주는 대신 아예 노출하지 않는다.
    private var matchBackAction: (() -> Void)? {
        guard selectedTab == 1 else { return nil }
        switch viewModel.phase {
        case .modeSelection:
            return { selectedTab = 0 }
        case .playing:
            guard viewModel.isDriver else { return nil }
            return {
                if hasMatchProgress {
                    showEndMatchConfirm = true
                } else {
                    viewModel.startNewMatch()
                }
            }
        case .finished:
            return { viewModel.startNewMatch() }
        }
    }

    /// 타이틀 자리 높이를 고정해 탭·phase 전환 때 툴바가 위아래로 흔들리지 않게 한다.
    /// 가장 큰 내용인 28pt 볼드 타이틀의 줄 높이 기준 (경과시간 표시는 이보다 낮다).
    private static let toolbarTitleHeight: CGFloat = 34

    /// 매치 탭 상단 타이틀 — 모드 선택 중에는 화면 이름, 경기 중에는 운동 경과시간.
    /// 워크아웃 탭에서는 내용을 비운다 — 자리(높이)는 위 고정값으로 유지된다.
    @ViewBuilder
    private var matchTitle: some View {
        if selectedTab == 1 {
            switch viewModel.phase {
            case .modeSelection:
                Text(String(localized: "new_match"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            case .playing, .finished:
                WorkoutIndicator(elapsedFormatted: viewModel.metrics.formattedElapsed)
            }
        } else {
            Color.clear.frame(width: 0)
        }
    }

    @ViewBuilder
    private var scoreTabContent: some View {
        switch viewModel.phase {
        case .modeSelection:
            ModeView(viewModel: viewModel)

        case .playing:
            ScoreView(
                viewModel: viewModel.scoreVM,
                isDriver: viewModel.isDriver,
                onMatchFinished: { result, sets in
                    viewModel.finishMatch(result: result, completedSets: sets)
                },
                onProgressChanged: { hasMatchProgress = $0 }
            )

        case let .finished(session):
            MatchResultView(session: session, viewModel: viewModel)
                .id(session.workoutSessionId)
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutSessionView(onExit: {})
            .preferredColorScheme(.dark)
    }
}
