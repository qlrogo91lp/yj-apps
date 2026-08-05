import SwiftUI

struct HomeView: View {
    @State private var isRoundActive = false
    @State private var resumingSnapshot: RoundSnapshot?

    private let publisher = RoundSnapshotPublisher()

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Spacer()

                Text("Golf Counter")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.green)
                Button {
                    resumingSnapshot = nil
                    isRoundActive = true
                } label: {
                    Text("라운드 시작")
                        .font(.system(size: 16, weight: .bold))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Spacer()
            }
            .navigationDestination(isPresented: $isRoundActive) {
                RoundSessionView(resuming: resumingSnapshot)
            }
        }
        .onAppear(perform: resumeIfNeeded)
    }

    /// 크래시·강제종료 후 실행되면 진행 중 스냅샷으로 라운드를 이어간다 (spec §12).
    /// 워크아웃 세션은 복구하지 않고 RoundSessionView가 새로 시작한다.
    private func resumeIfNeeded() {
        guard !isRoundActive, let snapshot = publisher.loadCurrent() else { return }
        resumingSnapshot = snapshot
        isRoundActive = true
    }
}

#Preview {
    HomeView()
}
