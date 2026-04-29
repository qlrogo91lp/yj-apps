import SwiftData
import SwiftUI

struct MatchView: View {
    let format: MatchFormat

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MatchViewModel

    init(format: MatchFormat) {
        self.format = format
        _viewModel = StateObject(wrappedValue: MatchViewModel(format: format))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.isMatchOver {
                matchOverView
            } else {
                VStack(spacing: 0) {
                    headerView
                    if format == .bestOfThree {
                        setHistoryBar
                    }
                    scoreInputView
                    confirmButton
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.injectContext(modelContext)
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            if format == .bestOfThree {
                Text(String(format: String(localized: "set_indicator_format"), viewModel.currentSetNumber))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }

            Text("\(viewModel.myGameScore)")
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(.green)

            Text(":")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)

            Text("\(viewModel.yourGameScore)")
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(.orange)

            Spacer()

            Button(action: { viewModel.resetAll() }) {
                Text(String(localized: "btn_reset"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.borderless)
        }
        .padding(.bottom, 8)
    }

    private var setHistoryBar: some View {
        HStack(spacing: 16) {
            ForEach(viewModel.completedSets.indices, id: \.self) { idx in
                let set = viewModel.completedSets[idx]
                HStack(spacing: 4) {
                    Text("\(set.my)")
                        .foregroundColor(.green)
                    Text("-")
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(set.your)")
                        .foregroundColor(.orange)
                }
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .clipShape(Capsule())
            }
            Spacer()

            HStack(spacing: 8) {
                Text("\(viewModel.mySetScore)")
                    .foregroundColor(.green)
                    .font(.system(size: 18, weight: .bold))
                Text(String(localized: "set_indicator_format").replacingOccurrences(of: "%d", with: ""))
                    .foregroundColor(.white.opacity(0.5))
                    .font(.system(size: 14))
                Text("\(viewModel.yourSetScore)")
                    .foregroundColor(.orange)
                    .font(.system(size: 18, weight: .bold))
            }
        }
        .padding(.vertical, 8)
    }

    private var scoreInputView: some View {
        HStack {
            CounterButtonView(flag: 0, score: viewModel.score)
            Spacer()
            Text(":")
                .font(.system(size: 25, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            CounterButtonView(flag: 1, score: viewModel.score)
        }
        .padding(.vertical)
    }

    private var confirmButton: some View {
        Button(action: { viewModel.confirmScore() }) {
            Text(String(localized: "btn_confirm"))
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.blue)
        }
    }

    private var matchOverView: some View {
        VStack(spacing: 20) {
            Text(viewModel.didWin
                 ? String(localized: "match_over_win")
                 : String(localized: "match_over_lose"))
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(viewModel.didWin ? .green : .orange)

            HStack(spacing: 24) {
                ForEach(viewModel.completedSets.indices, id: \.self) { idx in
                    let set = viewModel.completedSets[idx]
                    VStack(spacing: 2) {
                        Text("Set \(idx + 1)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                        HStack(spacing: 4) {
                            Text("\(set.my)").foregroundColor(.green)
                            Text("-").foregroundColor(.white.opacity(0.5))
                            Text("\(set.your)").foregroundColor(.orange)
                        }
                        .font(.system(size: 18, weight: .bold))
                    }
                }
            }

            Button(action: {
                viewModel.resetAll()
                dismiss()
            }) {
                Text(String(localized: "btn_new_match"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)
        }
        .padding()
    }
}

struct MatchView_Previews: PreviewProvider {
    static var previews: some View {
        MatchView(format: .bestOfThree)
    }
}
