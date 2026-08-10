import SwiftUI
import WatchKit

/// 카운터의 세로 1페이지 — 헤더·현재 홀 점수·타수 버튼·모드/Par·홀 이동.
///
/// 어떤 크기 세트를 쓸지는 이 뷰가 정하지 않는다. `CounterView`의 `ViewThatFits`가
/// 화면에 실제로 들어가는 세트를 골라 `sizing`으로 넘겨준다.
struct CounterPage: View {
    @ObservedObject var viewModel: RoundViewModel
    let sizing: CounterSizing

    var body: some View {
        VStack(spacing: sizing.spacing) {
            header
            currentHoleScore
            strokeButtons
            modeAndPar
            HoleNavigation(canGoToPrevious: viewModel.canGoToPreviousHole,
                           height: sizing.navHeight,
                           onPrevious: viewModel.goToPreviousHole,
                           onNext: viewModel.goToNextHole)
        }
        .padding(.horizontal, 4)
    }

    private var header: some View {
        HStack {
            Text("H\(viewModel.currentHoleNumber) · Par \(viewModel.currentPar)")
                .font(.system(size: sizing.headerFont, weight: .semibold))
            Spacer()
            Text(ScoreFormat.relativeToPar(viewModel.relativeToPar))
                .font(.system(size: sizing.headerFont, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
        }
    }

    private var currentHoleScore: some View {
        Text("\(viewModel.currentScore)타 · \(viewModel.currentPutts)퍼트")
            .font(.system(size: sizing.scoreFont, weight: .bold, design: .rounded))
            .contentTransition(.numericText())
    }

    private var strokeButtons: some View {
        HStack(spacing: 12) {
            StrokeButton(systemName: "plus",
                         tint: .green,
                         size: sizing.strokeButton,
                         iconSize: sizing.strokeIcon)
            {
                viewModel.incrementStroke()
                WKInterfaceDevice.current().play(.click)
            }
            StrokeButton(systemName: "minus",
                         tint: .orange,
                         size: sizing.strokeButton,
                         iconSize: sizing.strokeIcon)
            {
                viewModel.decrementStroke()
                WKInterfaceDevice.current().play(.directionDown)
            }
        }
    }

    private var modeAndPar: some View {
        HStack(spacing: 4) {
            ModeToggle(mode: $viewModel.inputMode, height: sizing.controlHeight)
            Button {
                viewModel.beginParEditing()
            } label: {
                Text("Par")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(minWidth: 44, minHeight: sizing.controlHeight)
            }
            .buttonStyle(.plain)
            .background(Color.gray.opacity(0.25), in: Capsule())
        }
    }
}

#Preview {
    let viewModel = RoundViewModel()
    viewModel.selectPar(4)
    viewModel.incrementStroke()
    return CounterPage(viewModel: viewModel, sizing: .regular)
}
