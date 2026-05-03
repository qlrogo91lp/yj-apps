import SwiftUI

struct MatchView: View {
    @StateObject var viewModel = MatchViewModel()

    var body: some View {
        if viewModel.isMatchOver {
            matchOverView
        } else {
            TabView {
                scorePageView
                    .tag(0)

                ExerciseView(healthKit: viewModel.healthKit)
                    .tag(1)
            }
            .tabViewStyle(.page)
            .onAppear { viewModel.startMatch() }
        }
    }

    // MARK: - Score Page

    private var scorePageView: some View {
        ZStack {
            HStack(spacing: 0) {
                Button(action: { viewModel.addMyPoint() }) {
                    ZStack {
                        Color.green.opacity(0.15)
                        VStack(spacing: 4) {
                            Text("ME")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.green)
                            Text(viewModel.score.myScore == 50 ? "W" : "\(viewModel.score.myScore)")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.green)
                                .contentTransition(.numericText())
                        }
                    }
                }
                .buttonStyle(.plain)

                Button(action: { viewModel.addYourPoint() }) {
                    ZStack {
                        Color.orange.opacity(0.15)
                        VStack(spacing: 4) {
                            Text("OPP")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.orange)
                            Text(viewModel.score.yourScore == 50 ? "W" : "\(viewModel.score.yourScore)")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.orange)
                                .contentTransition(.numericText())
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .ignoresSafeArea()

            VStack {
                HStack(spacing: 10) {
                    Text("\(viewModel.myGameScore)")
                        .foregroundColor(.green)
                        .contentTransition(.numericText())
                    Text("SET")
                        .foregroundColor(.white)
                    Text("\(viewModel.yourGameScore)")
                        .foregroundColor(.orange)
                        .contentTransition(.numericText())
                }
                .font(.system(size: 16, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.8))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))

                Spacer()

                if viewModel.score.lastAction != .none {
                    Button(action: { viewModel.undo() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Undo")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 25)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.2), value: viewModel.score.lastAction)
        }
    }

    // MARK: - Match Over

    private var matchOverView: some View {
        VStack(spacing: 12) {
            Text(viewModel.didWin ? "Victory!" : "Defeat")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(viewModel.didWin ? .green : .orange)

            HStack {
                Text("\(viewModel.mySetScore)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.green)
                Text(":")
                    .font(.system(size: 26, weight: .bold))
                Text("\(viewModel.yourSetScore)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.orange)
            }

            Button(action: { viewModel.startNewMatch() }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                    Text("New Match")
                        .font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .padding()
    }
}

struct MatchView_Previews: PreviewProvider {
    static var previews: some View {
        MatchView()
    }
}
