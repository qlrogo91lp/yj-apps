import SwiftUI
import WorkoutUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: WorkoutViewModel

    var body: some View {
        switch viewModel.phase {
        case .idle:
            startScreen
        case .active:
            sessionPages
        case .summary:
            SummaryView(viewModel: viewModel)
        }
    }

    /// W1 — 지표 / 컨트롤 세로 페이징. 모드 라벨과 전환 행은 `WorkoutUI` 확장으로 붙는다 (D-M1).
    private var sessionPages: some View {
        TabView {
            WorkoutMetricsView(metrics: viewModel.metrics,
                               isPaused: viewModel.isPaused,
                               statusText: "진행 중 · \(viewModel.mode.title)")
            WorkoutControlsView(
                isPaused: viewModel.isPaused,
                modeSelection: modeSelection,
                onPauseResume: { viewModel.togglePause() },
                onEnd: { Task { await viewModel.end() } }
            )
        }
        .tabViewStyle(.verticalPage)
    }

    /// 전환 행에 넘길 값. **제목과 색을 앱이 소유한다** — `WorkoutUI` 는 근력·유산소를 모른다.
    private var modeSelection: WorkoutModeSelection {
        WorkoutModeSelection(
            options: SegmentKind.allCases.enumerated().map { index, kind in
                WorkoutModeOption(id: index,
                                  title: kind.title,
                                  tint: kind == .strength ? .brandOrange : .blue)
            },
            selectedID: SegmentKind.allCases.firstIndex(of: viewModel.mode) ?? 0,
            onSelect: { index in
                let kinds = SegmentKind.allCases
                guard kinds.indices.contains(index) else { return }
                viewModel.switchMode(to: kinds[index])
            }
        )
    }

    /// W0 — 최소 골격. 시작 유형 토글·잔디·오늘 요약은 후속 플랜이다.
    private var startScreen: some View {
        VStack(spacing: 12) {
            Text("Haruchi Fit")
                .font(.headline)
                .foregroundStyle(Color.brandOrange)
            Button("운동 시작") { viewModel.start() }
                .buttonStyle(.borderedProminent)
        }
    }
}
