import SwiftUI
import WorkoutUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: WorkoutViewModel
    /// 스파이크 전용. 검증이 끝나면 이 상태와 아래 버튼·sheet 를 지운다.
    @State private var showSpike = false

    var body: some View {
        if viewModel.isActive {
            sessionPages
        } else {
            startScreen
        }
    }

    /// W1 — 지표 / 컨트롤 세로 페이징. 모드 라벨과 전환 행은 후속 플랜(D-M1)이다.
    private var sessionPages: some View {
        TabView {
            WorkoutMetricsView(metrics: viewModel.metrics, isPaused: viewModel.isPaused)
            WorkoutControlsView(
                isPaused: viewModel.isPaused,
                onPauseResume: { viewModel.togglePause() },
                onEnd: { Task { await viewModel.end() } }
            )
        }
        .tabViewStyle(.verticalPage)
    }

    /// W0 — 최소 골격. 잔디와 오늘 요약은 후속 플랜이다.
    private var startScreen: some View {
        VStack(spacing: 12) {
            Text("Haruchi Fit")
                .font(.headline)
                .foregroundStyle(Color(red: 1.0, green: 0.58, blue: 0.0)) // #FF9500 브랜드 오렌지
            Button("운동 시작") { viewModel.start() }
                .buttonStyle(.borderedProminent)

            // 스파이크 전용 진입점. 검증이 끝나면 지운다.
            Button("구간 스파이크") { showSpike = true }
                .font(.footnote)
                .buttonStyle(.bordered)
        }
        .sheet(isPresented: $showSpike) { SpikeView() }
    }
}
