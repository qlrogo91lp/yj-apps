import SwiftUI
import WorkoutCore

struct RoundSessionView: View {
    @StateObject private var viewModel: RoundViewModel
    @StateObject private var healthKit = WorkoutSessionService(configuration: .golf)
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 1
    @State private var startTask: Task<Void, Never>?
    /// endRound()가 정상적으로 워크아웃을 끝냈는지 표시한다.
    /// false인 채로 뷰가 사라지면(edge-swipe 등 endRound() 밖의 경로) onDisappear에서 방어적으로 정리한다.
    @State private var didFinish = false

    /// 진행 중 스냅샷이 있으면 그 라운드를 이어서, 없으면 새 라운드를 시작한다.
    init(resuming snapshot: RoundSnapshot? = nil) {
        if let snapshot {
            _viewModel = StateObject(wrappedValue: RoundViewModel(resuming: snapshot))
        } else {
            _viewModel = StateObject(wrappedValue: RoundViewModel())
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SessionControlsView(isPaused: healthKit.isPaused,
                                onPauseResume: togglePause,
                                onEnd: endRound)
                .tag(0)
            centerPage
                .tag(1)
            SessionMetricsView(healthKit: healthKit)
                .tag(2)
        }
        .tabViewStyle(.page)
        .navigationBarBackButtonHidden()
        .onAppear(perform: startRound)
        .onDisappear(perform: stopWorkoutIfNotFinished)
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
        case .counting:
            ScoringView(viewModel: viewModel)
        case .summary:
            // 요약 화면 연결은 Task 9 범위. 지금은 Phase 열거형 완결성만 맞춘다.
            EmptyView()
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

    /// 워크아웃을 끝내고 스냅샷을 지운 뒤 홈으로 돌아간다.
    /// 종료 요약 화면과 iOS 전송은 plan ④에서 이 자리에 들어온다.
    /// 인증 대기 중이던 시작 Task를 먼저 취소해, 라운드 종료 후 뒤늦게 startWorkout()이
    /// 불려 고아 HKWorkoutSession이 남는 경쟁 상태를 막는다.
    private func endRound() {
        startTask?.cancel()
        didFinish = true
        viewModel.finishRound()
        let service = healthKit
        Task { _ = await service.stopWorkout() }
        dismiss()
    }

    /// endRound()를 거치지 않고 뷰가 사라지면(예: edge-swipe 뒤로가기) 워크아웃 세션이 고아로 남는다.
    /// 스냅샷/App Group 상태는 건드리지 않는다 — 크래시 복구는 HomeView의 resumeIfNeeded()가 계속 담당한다.
    /// TabView 내부 페이지 전환이 아니라 RoundSessionView 자체가 내비게이션 스택에서 빠질 때만 호출된다.
    private func stopWorkoutIfNotFinished() {
        guard !didFinish else { return }
        let service = healthKit
        Task { _ = await service.stopWorkout() }
    }
}
