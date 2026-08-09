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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if selectedTab == 1 {
                    matchBackButton
                } else {
                    // 툴바가 개별 탭이 아니라 TabView에 걸려 두 탭이 공유한다. 워크아웃 탭에
                    // 매치용 뒤로가기가 새어나가지 않도록 자리만 비운다 (워치와 같은 방식 —
                    // 슬롯을 없애면 .principal 아이템 위치가 흔들린다).
                    Color.clear.frame(width: 36, height: 36)
                }
            }
            ToolbarItem(placement: .principal) {
                switch viewModel.phase {
                case .modeSelection:
                    Text(String(localized: "new_match"))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                case .playing, .finished:
                    if selectedTab == 1 {
                        WorkoutIndicator(elapsedFormatted: viewModel.metrics.formattedElapsed)
                    }
                }
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
                viewModel.startMatch(options: remote.options, sessionId: remote.sessionId, isRemote: true)
            } else {
                viewModel.startSession()
            }
        }
        .onChange(of: viewModel.remoteWorkoutEnded) {
            if viewModel.remoteWorkoutEnded { onExit() }
        }
    }

    /// 매치 탭 전용 뒤로가기 — phase별로 동작이 다르다.
    /// `.playing`에서 진행 중인 매치를 끝낼 권한은 driver에게만 있다 (점수 입력·undo와 같은 규칙).
    /// mirror에게는 눌러도 아무 일 없는 버튼을 보여주는 대신 자리를 비운다.
    @ViewBuilder
    private var matchBackButton: some View {
        switch viewModel.phase {
        case .modeSelection:
            BackButton { selectedTab = 0 }
        case .playing:
            if viewModel.isDriver {
                BackButton {
                    if hasMatchProgress {
                        showEndMatchConfirm = true
                    } else {
                        viewModel.startNewMatch()
                    }
                }
            } else {
                Color.clear.frame(width: 36, height: 36)
            }
        case .finished:
            BackButton { viewModel.startNewMatch() }
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
