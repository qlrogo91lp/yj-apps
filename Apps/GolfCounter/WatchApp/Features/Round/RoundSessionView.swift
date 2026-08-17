import SwiftUI
import WorkoutCore

struct RoundSessionView: View {
    @StateObject private var viewModel: RoundViewModel
    @StateObject private var healthKit = WorkoutSessionService(configuration: .golf)
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 1
    @State private var startTask: Task<Void, Never>?
    @State private var isConfirmingEnd = false
    /// endRound()가 정상적으로 워크아웃을 끝냈는지 표시한다.
    /// false인 채로 뷰가 사라지면(edge-swipe 등 endRound() 밖의 경로) onDisappear에서 방어적으로 정리한다.
    @State private var didFinish = false

    /// 진행 중 스냅샷이 있으면 그 라운드를 이어서, 없으면 고른 홀 수로 새 라운드를 시작한다.
    /// 복구 라운드는 홈의 선택값을 무시하고 스냅샷의 `holeCount`를 쓴다.
    init(resuming snapshot: RoundSnapshot? = nil, holeCount: Int = 18) {
        if let snapshot {
            _viewModel = StateObject(wrappedValue: RoundViewModel(resuming: snapshot))
        } else {
            _viewModel = StateObject(wrappedValue: RoundViewModel(holeCount: holeCount))
        }
    }

    /// 요약이면 3페이지 TabView를 통째로 대체한다 — 종료 후에는 컨트롤·메트릭 페이지가
    /// 의미를 잃으므로 그쪽으로 스와이프할 수 없어야 한다 (spec §3.2).
    ///
    /// `Group`이 아니라 `ZStack`인 이유: `Group`은 modifier를 분기마다 개별 적용해
    /// 전환 시 `onAppear`가 재발화하고 `startRound()`가 다시 돈다.
    var body: some View {
        ZStack {
            if viewModel.phase == .summary {
                SummaryView(viewModel: viewModel)
            } else {
                sessionTabs
            }
        }
        .navigationBarBackButtonHidden()
        .onAppear(perform: startRound)
        .onDisappear(perform: stopWorkoutIfNotFinished)
        .onChange(of: viewModel.didComplete) { _, completed in
            if completed { dismiss() }
        }
        .confirmationDialog(endDialogTitle,
                            isPresented: $isConfirmingEnd,
                            titleVisibility: .visible)
        {
            Button(endDialogConfirmLabel, role: .destructive, action: endRound)
            Button(String(localized: "common_cancel"), role: .cancel) {}
        }
    }

    private var sessionTabs: some View {
        TabView(selection: $selectedTab) {
            SessionControlsView(isPaused: healthKit.isPaused,
                                onPauseResume: togglePause,
                                onEnd: { isConfirmingEnd = true })
                .tag(0)
            centerPage
                .tag(1)
            SessionMetricsView(healthKit: healthKit)
                .tag(2)
        }
        .tabViewStyle(.page)
    }

    /// 트림 후 실제로 몇 홀이 기록되는지를 문구에 명시한다 (spec §2 결정 4).
    private var endDialogTitle: String {
        viewModel.recordedHoleCount > 0
            ? String(format: String(localized: "round_end_title_recorded"), viewModel.recordedHoleCount)
            : String(localized: "round_end_title_empty")
    }

    private var endDialogConfirmLabel: String {
        viewModel.recordedHoleCount > 0
            ? String(localized: "round_end_confirm")
            : String(localized: "round_end_confirm_empty")
    }

    private func togglePause() {
        if healthKit.isPaused {
            healthKit.resumeWorkout()
        } else {
            healthKit.pauseWorkout()
        }
    }

    @ViewBuilder
    private var centerPage: some View {
        switch viewModel.phase {
        case .parSelection:
            ParSelectionView(viewModel: viewModel)
        case .counting, .summary:
            ScoringView(viewModel: viewModel)
        }
    }

    private func startRound() {
        viewModel.start()
        startTask = Task {
            await healthKit.requestAuthorization()
            guard !Task.isCancelled else { return }
            healthKit.startWorkout()
        }
    }

    /// 종료 확인을 거친 뒤 호출된다. 워크아웃을 끝내고 요약으로 전환하며,
    /// 집계값은 도착하는 대로 ViewModel에 넘긴다 — 화면은 기다리지 않는다 (spec §7).
    ///
    /// 인증 대기 중이던 시작 Task를 먼저 취소해, 라운드 종료 후 뒤늦게 startWorkout()이
    /// 불려 고아 HKWorkoutSession이 남는 경쟁 상태를 막는다.
    private func endRound() {
        startTask?.cancel()
        didFinish = true
        viewModel.finishRound()
        let service = healthKit
        Task {
            let result = await service.stopWorkout()
            viewModel.applyMetrics(result.map(RoundMetrics.init))
        }
    }

    /// endRound()를 거치지 않고 뷰가 사라지면(예: edge-swipe 뒤로가기) 워크아웃 세션이 고아로 남는다.
    /// 스냅샷/App Group 상태는 건드리지 않는다 — 전송 없이 요약을 벗어난 라운드는 스냅샷이
    /// 남아 다음 실행 때 복구된다 (spec §2 결정 6).
    private func stopWorkoutIfNotFinished() {
        guard !didFinish else { return }
        let service = healthKit
        Task { _ = await service.stopWorkout() }
    }
}
