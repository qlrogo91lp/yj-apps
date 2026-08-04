import SwiftUI

struct ParSelectionView: View {
    @ObservedObject var viewModel: RoundViewModel

    var body: some View {
        VStack(spacing: 6) {
            Text("H\(viewModel.currentHoleNumber)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach([3, 4, 5], id: \.self) { par in
                ParOptionButton(par: par, isSelected: viewModel.currentPar == par) {
                    viewModel.selectPar(par)
                }
            }

            ParBackButton(canGoToPrevious: viewModel.canGoToPreviousHole,
                          action: viewModel.cancelToPreviousHole)
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    ParSelectionView(viewModel: RoundViewModel())
}
