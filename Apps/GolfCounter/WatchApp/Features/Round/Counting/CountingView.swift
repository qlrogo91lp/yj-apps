import SwiftUI
import WatchKit

struct CountingView: View {
    @ObservedObject var viewModel: RoundViewModel
    let sizing: CountingSizing

    /// Always-On(손목 내림) 상태에서는 애니메이션을 돌리지 않는다.
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    /// 링 존의 가로 패딩. 헤더는 이 값을 쓰지 않는다 — 세로 페이지 인디케이터를 피해
    /// 더 안쪽으로 물러나야 하므로 `CountingSizing.pageIndicatorInset`을 따로 쓴다.
    private let horizontalPadding: CGFloat = 4

    var body: some View {
        // `HoleHeader`는 내부 `Spacer` 때문에 항상 전체 폭을 채우지만, `ringArea`는
        // 고정 폭(화살표+링+화살표)이라 그보다 좁다 — 기본 `.center` 정렬을 쓰면
        // VStack이 ringArea를 가운데로 밀어서 화살표·취소의 x가 Par와 어긋난다.
        // `.leading`으로 두 블록의 왼쪽 원점을 강제로 맞춘다.
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: sizing.spacing) {
                HoleHeader(holeNumber: viewModel.currentHoleNumber,
                           totalStrokes: viewModel.totalStrokes,
                           par: viewModel.currentPar,
                           mode: $viewModel.inputMode,
                           sizing: sizing,
                           onEditPar: viewModel.beginParEditing)
                    .padding(.horizontal, CountingSizing.pageIndicatorInset)

                ringArea
                    .padding(.horizontal, horizontalPadding)
            }

            Spacer(minLength: 0)
        }
        .animation(fillAnimation, value: viewModel.currentScore)
        .animation(fillAnimation, value: viewModel.canUndo)
    }


    private var fillAnimation: Animation? {
        isLuminanceReduced ? nil : .easeOut(duration: 0.18)
    }

    private var ringArea: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack {
                CircleIconButton(systemName: "chevron.left",
                                 size: sizing.arrowSize,
                                 action: viewModel.goToPreviousHole)
                    .disabled(!viewModel.canGoToPreviousHole)
                    .opacity(viewModel.canGoToPreviousHole ? 1 : 0.35)
                    .frame(width: sizing.arrowSize, height: CountingSizing.arrowHitHeight)
                    .contentShape(Rectangle())

                Spacer()

                ring

                Spacer()

                CircleIconButton(systemName: "chevron.right",
                                 size: sizing.arrowSize,
                                 action: viewModel.goToNextHole)
                    .frame(width: sizing.arrowSize, height: CountingSizing.arrowHitHeight)
                    .contentShape(Rectangle())
            }

            undoOverlay
        }
    }

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

    @ViewBuilder
    private var undoOverlay: some View {
        if viewModel.canUndo {
            CircleIconButton(systemName: "arrow.uturn.backward",
                             size: sizing.headerButtonSize,
                             hitInset: CountingSizing.undoHitInset,
                             action: undo)
                .padding(.trailing, CountingSizing.pageIndicatorInset - horizontalPadding)
                .offset(y: CountingSizing.undoBottomOffset)
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
