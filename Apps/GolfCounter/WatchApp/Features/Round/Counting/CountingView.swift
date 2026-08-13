import SwiftUI
import WatchKit

/// 카운터의 세로 1페이지 — 상단 정보행 · 링 · 하단 조작행 세 블록이다 (spec §5).
///
/// 어떤 크기 세트를 쓸지는 이 뷰가 정하지 않는다. `CounterView`의 `ViewThatFits`가
/// 화면에 실제로 들어가는 세트를 골라 `sizing`으로 넘겨준다.
struct CountingView: View {
    @ObservedObject var viewModel: RoundViewModel
    let sizing: CountingSizing

    /// Always-On(손목 내림) 상태에서는 애니메이션을 돌리지 않는다.
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        VStack(spacing: sizing.spacing) {
            CounterHeader(holeNumber: viewModel.currentHoleNumber,
                          par: viewModel.currentPar,
                          totalStrokes: viewModel.totalStrokes,
                          canUndo: viewModel.canUndo,
                          sizing: sizing,
                          onEditPar: viewModel.beginParEditing,
                          onUndo: undo)

            ringArea

            CounterControls(mode: $viewModel.inputMode,
                            canGoToPrevious: viewModel.canGoToPreviousHole,
                            sizing: sizing,
                            onPrevious: viewModel.goToPreviousHole,
                            onNext: viewModel.goToNextHole)
        }
        .padding(.horizontal, 4)
        .animation(fillAnimation, value: viewModel.currentScore)
        .animation(fillAnimation, value: viewModel.canUndo)
    }

    /// 한 홀에 연속으로 여러 번 누를 수 있어 길면 다음 탭에서 애니메이션이 겹쳐 밀린다.
    /// 값 기반이라 진행 중 새 값이 들어오면 그쪽으로 바로 따라간다.
    private var fillAnimation: Animation? {
        isLuminanceReduced ? nil : .easeOut(duration: 0.18)
    }

    /// 링 · 가운데 숫자 · 탭 타깃을 겹쳐 놓는다.
    /// 탭 타깃은 맨 위에 두되 링 안쪽 원반으로 한정한다 — 링 호와 그 바깥은 탭 영역이 아니다.
    private var ringArea: some View {
        ZStack {
            StrokeRing(segments: segments, sizing: sizing)

            VStack(spacing: 0) {
                Text("\(viewModel.currentScore)")
                    .font(.system(size: sizing.scoreFont, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())
                Text(ScoreFormat.relativeToPar(viewModel.relativeToPar))
                    .font(.system(size: sizing.relativeFont, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Button(action: addStroke) {
                Circle()
                    .fill(.clear)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .frame(width: sizing.innerDiameter, height: sizing.innerDiameter)
        }
    }

    private var segments: RingSegments {
        RingSegments(par: viewModel.currentPar,
                     strokes: viewModel.currentScore,
                     putts: viewModel.currentPutts)
    }

    private func addStroke() {
        viewModel.incrementStroke()
        WKInterfaceDevice.current().play(.click)
    }

    private func undo() {
        viewModel.undo()
        WKInterfaceDevice.current().play(.directionDown)
    }
}

#Preview {
    let viewModel = RoundViewModel()
    viewModel.selectPar(4)
    viewModel.incrementStroke()
    return CountingView(viewModel: viewModel, sizing: .regular)
}
