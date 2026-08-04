import SwiftUI
import WatchKit

struct CounterView: View {
    @ObservedObject var viewModel: RoundViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                header
                currentHoleScore
                strokeButtons
                modeAndPar
                HoleNavigation(canGoToPrevious: viewModel.canGoToPreviousHole,
                               onPrevious: viewModel.goToPreviousHole,
                               onNext: viewModel.goToNextHole)

                Divider().padding(.top, 4)
                Scorecard(snapshot: viewModel.snapshot)
            }
            .padding(.horizontal, 4)
        }
    }

    private var header: some View {
        HStack {
            Text("H\(viewModel.currentHoleNumber) · Par \(viewModel.currentPar)")
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Text(ScoreFormat.relativeToPar(viewModel.relativeToPar))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.green)
        }
    }

    private var currentHoleScore: some View {
        Text("\(viewModel.currentScore)타 · \(viewModel.currentPutts)퍼트")
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .contentTransition(.numericText())
    }

    private var strokeButtons: some View {
        HStack(spacing: 12) {
            StrokeButton(systemName: "plus", tint: .green) {
                viewModel.incrementStroke()
                WKInterfaceDevice.current().play(.click)
            }
            StrokeButton(systemName: "minus", tint: .orange) {
                viewModel.decrementStroke()
                WKInterfaceDevice.current().play(.directionDown)
            }
        }
    }

    private var modeAndPar: some View {
        HStack(spacing: 4) {
            ModeToggle(mode: $viewModel.inputMode)
            Button {
                viewModel.beginParEditing()
            } label: {
                Text("Par")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(minWidth: 44, minHeight: 28)
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
    return CounterView(viewModel: viewModel)
}
