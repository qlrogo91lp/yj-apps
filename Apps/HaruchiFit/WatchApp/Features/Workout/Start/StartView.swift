import SwiftUI

/// W0 — 시작 유형 토글까지. 잔디와 오늘 요약은 후속 플랜이다.
struct StartView: View {
    @ObservedObject var viewModel: WorkoutViewModel

    var body: some View {
        // 제목은 위, 시작은 가운데, 유형 토글은 아래 — 손가락이 닿기 쉬운 곳에 눌러야 할 것을 둔다.
        VStack(spacing: 12) {
            Text(verbatim: "Haruchi Fit")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.brandOrange)

            Spacer(minLength: 0)

            Button { Task { await viewModel.start() } } label: {
                Text("start_workout")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brandOrange)
            .disabled(viewModel.isStarting)

            Spacer(minLength: 0)

            startKindToggle
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    /// 유형 선택 화면을 토글 한 줄로 흡수했다 — 2개뿐이라 피커가 불필요하고 화살표도 두지 않는다.
    /// **CTA 색은 오렌지 고정**이고, 유형 구분은 이 텍스트 색으로만 한다 (제품 스펙 W0).
    private var startKindToggle: some View {
        Button { viewModel.toggleStartKind() } label: {
            HStack {
                Text("start_kind_label")
                    .foregroundStyle(.secondary)
                Spacer()
                // 글자만 있으면 설명 문구로 읽힌다 — 세션 화면 아이콘처럼 같은 색 연한 배경을 깐다.
                Text(shortTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 32)
                    .background(tint.opacity(0.2), in: Capsule())
            }
            .font(.system(size: 16))
            // Spacer 는 그리는 게 없어 기본 히트테스트에서 빠진다 — 가운데를 눌러도
            // 반응하지 않는다. 손가락이 큰 워치에서 글자만 한 과녁은 너무 좁다.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 영어 "Strength" 는 캡슐에서 잘린다 — 이 자리만 짧은 표기를 쓴다. 다른 화면은 `mode.title` 그대로다.
    private var shortTitle: String {
        switch viewModel.mode {
        case .strength: String(localized: "start_kind_strength_short")
        case .cardio: String(localized: "start_kind_cardio_short")
        }
    }

    private var tint: Color {
        viewModel.mode == .strength ? .brandOrange : .blue
    }
}
