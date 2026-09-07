import SwiftUI
import WorkoutUI

/// W1 — 지표 / 컨트롤 세로 페이징. 모드 라벨과 전환 행은 `WorkoutUI` 확장으로 붙는다 (D-M1).
struct SessionView: View {
    @ObservedObject var viewModel: WorkoutViewModel

    var body: some View {
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
}
