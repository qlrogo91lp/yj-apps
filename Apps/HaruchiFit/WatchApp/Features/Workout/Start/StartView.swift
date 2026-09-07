import SwiftUI

/// W0 — 최소 골격. 시작 유형 토글·잔디·오늘 요약은 후속 플랜이다.
struct StartView: View {
    @ObservedObject var viewModel: WorkoutViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text("Haruchi Fit")
                .font(.headline)
                .foregroundStyle(Color.brandOrange)
            Button("운동 시작") { viewModel.start() }
                .buttonStyle(.borderedProminent)
        }
    }
}
