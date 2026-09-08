import SwiftUI

/// W0 — 시작 유형 토글까지. 잔디와 오늘 요약은 후속 플랜이다.
struct StartView: View {
    @ObservedObject var viewModel: WorkoutViewModel

    var body: some View {
        VStack(spacing: 10) {
            Text("Haruchi Fit")
                .font(.headline)
                .foregroundStyle(Color.brandOrange)

            Button("운동 시작") { viewModel.start() }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandOrange)

            startKindToggle
        }
        .padding(.horizontal, 8)
    }

    /// 유형 선택 화면을 토글 한 줄로 흡수했다 — 2개뿐이라 피커가 불필요하고 화살표도 두지 않는다.
    /// **CTA 색은 오렌지 고정**이고, 유형 구분은 이 텍스트 색으로만 한다 (제품 스펙 W0).
    private var startKindToggle: some View {
        Button { viewModel.toggleStartKind() } label: {
            HStack {
                Text("시작 운동")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(viewModel.mode.title)
                    .foregroundStyle(viewModel.mode == .strength ? Color.brandOrange : .blue)
            }
            .font(.system(size: 14))
            // Spacer 는 그리는 게 없어 기본 히트테스트에서 빠진다 — 가운데를 눌러도
            // 반응하지 않는다. 손가락이 큰 워치에서 글자만 한 과녁은 너무 좁다.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
