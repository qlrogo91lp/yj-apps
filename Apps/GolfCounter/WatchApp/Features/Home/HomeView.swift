import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var isConfirmingNewRound = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Spacer()

                Text("Golf Counter")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.green)

                Button(action: startTapped) {
                    Text(viewModel.startButtonLabel)
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                HoleCountSelector(holeCount: viewModel.holeCount,
                                  onToggle: viewModel.toggleHoleCount)

                Spacer()
            }
            .padding(.horizontal, 8)
            .navigationDestination(isPresented: $viewModel.isRoundActive) {
                RoundSessionView(resuming: viewModel.resumingSnapshot,
                                 holeCount: viewModel.holeCount)
            }
            .confirmationDialog("진행 중인 라운드가 있습니다",
                                isPresented: $isConfirmingNewRound,
                                titleVisibility: .visible)
            {
                Button("새로 시작", role: .destructive, action: viewModel.startNewRound)
                Button("취소", role: .cancel) {}
            } message: {
                Text("새로 시작하면 지워집니다.")
            }
        }
        .onAppear(perform: viewModel.resumeIfNeeded)
    }

    /// 전송 없이 요약을 벗어나면 스냅샷이 남는다(결정 6). 그대로 새 라운드를 시작하면
    /// start()가 곧바로 새 스냅샷을 발행해 이전 라운드를 덮어쓰므로 먼저 확인한다 (spec §3.6).
    private func startTapped() {
        if viewModel.hasPendingRound {
            isConfirmingNewRound = true
        } else {
            viewModel.startNewRound()
        }
    }
}

#Preview {
    HomeView()
}
