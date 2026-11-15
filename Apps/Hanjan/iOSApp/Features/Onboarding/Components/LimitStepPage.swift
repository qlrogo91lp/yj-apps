import SwiftUI

/// 온보딩 ① 평소 주량. 기본 8잔, 1~30 · 0.5 단위.
struct LimitStepPage: View {
    let limit: Double
    let onChange: (Double) -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            VStack(spacing: 10) {
                Text("평소 주량은\n소주 몇 잔인가요?")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("이 숫자를 오늘의 한도로 써요.\n설정에서 언제든 바꿀 수 있어요.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(SojuFormat.string(limit))
                    .font(.system(size: 72, weight: .bold).monospacedDigit())
                    .foregroundStyle(BrandColor.amber)
                Text("잔")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            Stepper(
                "소주 \(SojuFormat.string(limit))잔",
                value: Binding(get: { limit }, set: onChange),
                in: OnboardingViewModel.limitRange,
                step: OnboardingViewModel.limitStep
            )
            .labelsHidden()
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    LimitStepPage(limit: 8) { _ in }
        .background(BrandColor.background)
        .preferredColorScheme(.dark)
}
