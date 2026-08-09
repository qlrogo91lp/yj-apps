import SwiftUI
import WorkoutCore
import WorkoutUI

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
            WorkoutControlsView(isPaused: healthKit.isPaused,
                                onPauseResume: togglePause,
                                onEnd: endRound)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Color.clear.frame(width: 36, height: 36)
                    }
                }
                .tag(0)
            centerPage
                .tag(1)
            WorkoutMetricsView(metrics: currentMetrics, isPaused: healthKit.isPaused)
                .tag(2)
        }
        .tabViewStyle(.page)
        .navigationBarBackButtonHidden()
        .onAppear(perform: startRound)
        .onDisappear(perform: stopWorkoutIfNotFinished)
    }

    /// WorkoutUI의 공유 화면은 값 타입만 받는다 — 서비스의 현재 값을 스냅샷으로 옮긴다.
    /// healthKit이 이 View의 @StateObject라 관찰이 이미 걸려 있어 computed property로 충분하다.
    /// (테니스는 같은 매핑을 ViewModel의 @Published로 뺐는데, 그쪽은 View가 서비스를 소유하지 않아
    /// init에서 매번 새 인스턴스가 만들어지는 함정이 있었기 때문이다. 여기엔 그 함정이 없다.)
    private var currentMetrics: WorkoutMetrics {
        WorkoutMetrics(elapsedSeconds: TimeInterval(healthKit.elapsedSeconds),
                       activeCalories: healthKit.currentCalories,
                       totalCalories: healthKit.currentCalories + healthKit.currentBasalCalories,
                       heartRate: healthKit.currentHeartRate)
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
            CounterView(viewModel: viewModel)
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
        viewModel.finish()
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
