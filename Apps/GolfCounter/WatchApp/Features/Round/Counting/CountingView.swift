import SwiftUI
import WatchKit

struct CountingView: View {
    @ObservedObject var viewModel: RoundViewModel
    let sizing: CountingSizing
    let onRequestEnd: () -> Void

    /// Always-On(손목 내림) 상태에서는 애니메이션을 돌리지 않는다.
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    /// 한 타도 치지 않은 홀에서 `>`를 눌렀을 때의 확인. 실수로 홀을 날리는 것을 막는다.
    @State private var isConfirmingSkip = false

    var body: some View {
        // ringArea는 고정 폭이라 기본 .center 정렬로는 VStack이 가운데로 밀어버린다.
        // .leading으로 헤더·링의 왼쪽 원점을 맞춘다.
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
                    .padding(.horizontal, CountingSizing.ringHorizontalPadding)
            }

            Spacer(minLength: 0)
        }
        // UndoButton의 .transition도 이 애니메이션으로 구동된다.
        .animation(fillAnimation, value: viewModel.currentScore)
        .animation(fillAnimation, value: viewModel.canUndo)
        .confirmationDialog(String(localized: "counting_skip_title"),
                            isPresented: $isConfirmingSkip,
                            titleVisibility: .visible)
        {
            Button(String(localized: "counting_skip_confirm"), role: .destructive, action: viewModel.skipCurrentHole)
            Button(String(localized: "common_cancel"), role: .cancel) {}
        }
    }

    private var fillAnimation: Animation? {
        isLuminanceReduced ? nil : .easeOut(duration: 0.18)
    }

    /// 타수가 있으면 그냥 넘어가고, 한 타도 없으면 확인부터 받는다.
    private func goToNextHoleOrConfirm() {
        if viewModel.currentScore == 0 {
            isConfirmingSkip = true
        } else {
            viewModel.goToNextHole()
        }
    }

    private var ringArea: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack {
                HoleArrowButton(systemName: "chevron.left",
                                size: sizing.arrowSize,
                                isEnabled: viewModel.canGoToPreviousHole,
                                action: viewModel.goToPreviousHole)

                Spacer()

                ScoreRing(par: viewModel.currentPar,
                          strokes: viewModel.currentScore,
                          putts: viewModel.currentPutts,
                          relativeToPar: viewModel.relativeToPar,
                          sizing: sizing,
                          onTap: addStroke)

                Spacer()

                if viewModel.canGoToNextHole {
                    HoleArrowButton(systemName: "chevron.right",
                                    size: sizing.arrowSize,
                                    action: goToNextHoleOrConfirm)
                } else {
                    HoleArrowButton(systemName: "flag.checkered",
                                    size: sizing.arrowSize,
                                    action: onRequestEnd)
                }
            }

            if viewModel.canUndo {
                UndoButton(size: sizing.headerButtonSize, action: undo)
            }
        }
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
    return CountingView(viewModel: viewModel, sizing: .regular, onRequestEnd: {})
}
