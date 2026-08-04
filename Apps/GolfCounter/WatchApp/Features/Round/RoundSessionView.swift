import SwiftUI
import WorkoutCore

struct RoundSessionView: View {
    @StateObject private var viewModel: RoundViewModel
    @StateObject private var healthKit = WorkoutSessionService(configuration: .golf)
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 1

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
            ControlsView(healthKit: healthKit, onEndRound: endRound)
                .tag(0)
            centerPage
                .tag(1)
            MetricsView(healthKit: healthKit)
                .tag(2)
        }
        .tabViewStyle(.page)
        .navigationBarBackButtonHidden()
        .onAppear(perform: startRound)
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
        Task {
            await healthKit.requestAuthorization()
            healthKit.startWorkout()
        }
    }

    /// 워크아웃을 끝내고 스냅샷을 지운 뒤 홈으로 돌아간다.
    /// 종료 요약 화면과 iOS 전송은 plan ④에서 이 자리에 들어온다.
    private func endRound() {
        viewModel.finish()
        Task { _ = await healthKit.stopWorkout() }
        dismiss()
    }
}
