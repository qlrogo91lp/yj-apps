import SwiftUI
import WorkoutUI

/// W1 — 지표 / 컨트롤 세로 페이징. 지금 유형은 왼쪽 상단 아이콘이 알리고,
/// 전환 행은 `WorkoutUI` 확장으로 붙는다 (D-M1).
struct SessionView: View {
    @ObservedObject var viewModel: WorkoutViewModel

    var body: some View {
        // 화면을 쌓지 않는다 — 툴바가 놓일 내비게이션 바를 얻으려고 감쌀 뿐이다.
        NavigationStack {
            TabView {
                WorkoutMetricsView(metrics: viewModel.metrics, isPaused: viewModel.isPaused)
                WorkoutControlsView(
                    isPaused: viewModel.isPaused,
                    modeSelection: modeSelection,
                    onPauseResume: { viewModel.togglePause() },
                    onEnd: { Task { await viewModel.end() } }
                )
            }
            .tabViewStyle(.verticalPage)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    modeButton
                }
            }
        }
    }

    /// 왼쪽 상단 원형 아이콘. 지금 유형을 보여 주고, 누르면 반대 유형으로 넘긴다.
    private var modeButton: some View {
        let tint = tint(for: viewModel.mode)
        return Button {
            viewModel.switchMode(to: viewModel.mode == .strength ? .cardio : .strength)
        } label: {
            // `figure.*` 계열은 같은 폰트 크기에서도 다른 심볼보다 크게 그려진다.
            Image(systemName: symbolName(for: viewModel.mode))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.2), in: Circle())
        }
        .buttonStyle(.plain)
        .animation(.default, value: viewModel.mode)
        .accessibilityLabel(viewModel.mode.title)
    }

    /// 전환 행에 넘길 값. **제목과 색을 앱이 소유한다** — `WorkoutUI` 는 근력·유산소를 모른다.
    private var modeSelection: WorkoutModeSelection {
        WorkoutModeSelection(
            options: SegmentKind.allCases.enumerated().map { index, kind in
                WorkoutModeOption(id: index,
                                  title: kind.title,
                                  tint: tint(for: kind))
            },
            selectedID: SegmentKind.allCases.firstIndex(of: viewModel.mode) ?? 0,
            onSelect: { index in
                let kinds = SegmentKind.allCases
                guard kinds.indices.contains(index) else { return }
                viewModel.switchMode(to: kinds[index])
            }
        )
    }

    private func tint(for kind: SegmentKind) -> Color {
        kind == .strength ? .brandOrange : .blue
    }

    private func symbolName(for kind: SegmentKind) -> String {
        switch kind {
        case .strength: "figure.strengthtraining.traditional"
        case .cardio: "figure.run"
        }
    }
}
