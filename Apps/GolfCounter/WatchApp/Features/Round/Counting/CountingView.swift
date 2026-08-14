import SwiftUI
import WatchKit

/// 카운터의 세로 1페이지 — 헤더(Par · 홀·타수 · 모드)와 링 존(◁ 링 ▷) 두 블록,
/// 그리고 왼쪽 아래 코너에 뜨는 취소 오버레이로 이루어진다 (spec §5).
///
/// 헤더와 링 사이는 `Spacer`가 메운다 — 고정 간격 대신 세로 예산의 남는 몫을 그대로
/// 여백으로 돌려준다. 취소는 이 세로 스택 밖(`ZStack` 오버레이)에 있어 등장·퇴장이
/// 레이아웃을 밀어내지 않는다.
///
/// 어떤 크기 세트를 쓸지는 이 뷰가 정하지 않는다. `ScoringView`의 `ViewThatFits`가
/// 화면에 실제로 들어가는 세트를 골라 `sizing`으로 넘겨준다.
struct CountingView: View {
    @ObservedObject var viewModel: RoundViewModel
    let sizing: CountingSizing

    /// Always-On(손목 내림) 상태에서는 애니메이션을 돌리지 않는다.
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    /// `VStack`에 준 가로 패딩. 취소 오버레이의 x 정렬 계산이 이 값을 공유해야 하므로
    /// 매직 넘버로 두 곳에 흩어두지 않고 여기 하나로 둔다.
    private let horizontalPadding: CGFloat = 4

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(spacing: 0) {
                HoleHeader(holeNumber: viewModel.currentHoleNumber,
                           totalStrokes: viewModel.totalStrokes,
                           par: viewModel.currentPar,
                           mode: $viewModel.inputMode,
                           sizing: sizing,
                           onEditPar: viewModel.beginParEditing)

                Spacer(minLength: sizing.spacing)

                ringArea
            }
            .padding(.horizontal, horizontalPadding)

            undoOverlay
        }
        .animation(fillAnimation, value: viewModel.currentScore)
        .animation(fillAnimation, value: viewModel.canUndo)
    }

    /// 한 홀에 연속으로 여러 번 누를 수 있어 길면 다음 탭에서 애니메이션이 겹쳐 밀린다.
    /// 값 기반이라 진행 중 새 값이 들어오면 그쪽으로 바로 따라간다.
    private var fillAnimation: Animation? {
        isLuminanceReduced ? nil : .easeOut(duration: 0.18)
    }

    /// 링 존 — 이전/다음 홀 화살표가 링 좌우 세로 중앙에 붙는다. 화살표는 세로 공간을
    /// 쓰지 않는 죽은 자리(링 옆 여백)에 들어가므로 링 크기와 다투지 않는다.
    private var ringArea: some View {
        HStack(spacing: sizing.spacing) {
            CircleIconButton(systemName: "chevron.left",
                             size: sizing.arrowSize,
                             action: viewModel.goToPreviousHole)
                .disabled(!viewModel.canGoToPreviousHole)
                .opacity(viewModel.canGoToPreviousHole ? 1 : 0.35)

            ring

            CircleIconButton(systemName: "chevron.right",
                             size: sizing.arrowSize,
                             action: viewModel.goToNextHole)
        }
    }

    /// 링 · 가운데 텍스트 · 탭 타깃을 겹쳐 놓는다.
    /// 탭 타깃은 맨 위에 두되 링 안쪽 원반으로 한정한다 — 링 호와 그 바깥은 탭 영역이 아니다.
    /// 가운데는 이 홀 타수 · 파 대비 두 줄뿐이다 — 홀 번호·누적 타수는 헤더에 있다.
    private var ring: some View {
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

    /// 왼쪽 아래 코너 오버레이. 레이아웃 스택 밖에 있어 등장·퇴장이 헤더·링을 밀어내지 않는다.
    /// `‹`(이전 홀)와 세로로 충분히 떨어져 있어 서로 오탭하지 않는다.
    ///
    /// x축은 `‹`와 중심을 맞춘다 — 취소와 `‹`가 다른 지름(`undoSize` vs `arrowSize`)이라
    /// 왼쪽 끝을 맞추면 중심이 어긋나 보이므로, 두 원의 중심이 같은 x에 오도록
    /// 지름 차이의 절반만큼 안쪽 여백을 보정한다.
    @ViewBuilder
    private var undoOverlay: some View {
        if viewModel.canUndo {
            CircleIconButton(systemName: "arrow.uturn.backward",
                             size: sizing.undoSize,
                             action: undo)
                .padding(.leading, horizontalPadding + (sizing.arrowSize - sizing.undoSize) / 2)
                .padding(.bottom, 2)
                .transition(.scale.combined(with: .opacity))
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
