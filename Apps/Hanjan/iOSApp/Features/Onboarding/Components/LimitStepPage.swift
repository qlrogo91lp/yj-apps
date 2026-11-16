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
            HStack(spacing: 16) {
                LimitAdjustButton(limit: limit, direction: -1, onChange: onChange)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    ZStack(alignment: .trailing) {
                        Text("30.5")
                            .hidden()
                        Text(SojuFormat.string(limit))
                            .foregroundStyle(BrandColor.amber)
                            .contentTransition(.numericText(value: limit))
                            .animation(.easeInOut(duration: 0.2), value: limit)
                    }
                    .font(.system(size: 72, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    Text("잔")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: adjust(1)
                    case .decrement: adjust(-1)
                    @unknown default: break
                    }
                }
                LimitAdjustButton(limit: limit, direction: 1, onChange: onChange)
            }
            .sensoryFeedback(.selection, trigger: limit)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func adjust(_ direction: Double) {
        let range = OnboardingViewModel.limitRange
        onChange(min(range.upperBound, max(range.lowerBound, limit + direction * OnboardingViewModel.limitStep)))
    }
}

private struct LimitAdjustButton: View {
    let limit: Double
    let direction: Double
    let onChange: (Double) -> Void
    @State private var repeatTask: Task<Void, Never>?
    @State private var repeated = false
    @State private var repeatValue = 0.0
    @GestureState private var pressing = false

    private var disabled: Bool {
        direction < 0 ? limit <= OnboardingViewModel.limitRange.lowerBound : limit >= OnboardingViewModel.limitRange.upperBound
    }

    var body: some View {
        Button {
            if !repeated { change(from: limit) }
            repeated = false
        } label: {
            Image(systemName: direction < 0 ? "minus" : "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(direction < 0 ? Color.white : BrandColor.amber)
                .frame(width: 64, height: 64)
                .background(BrandColor.surface, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.3 : 1)
        .accessibilityLabel(direction < 0 ? "0.5잔 줄이기" : "0.5잔 늘리기")
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($pressing) { _, state, _ in state = true }
        )
        .onChange(of: pressing) { _, isPressing in
            if isPressing {
                repeated = false
                repeatValue = limit
                repeatTask?.cancel()
                repeatTask = Task { @MainActor in
                    do {
                        try await Task.sleep(for: .milliseconds(400))
                        while !Task.isCancelled {
                            repeated = true
                            change(from: repeatValue)
                            try await Task.sleep(for: .milliseconds(120))
                        }
                    } catch { return }
                }
            } else {
                repeatTask?.cancel()
                repeatTask = nil
            }
        }
        .onDisappear { repeatTask?.cancel() }
    }

    private func change(from value: Double) {
        let range = OnboardingViewModel.limitRange
        repeatValue = min(range.upperBound, max(range.lowerBound, value + direction * OnboardingViewModel.limitStep))
        if repeatValue != value { onChange(repeatValue) }
    }
}

#Preview {
    LimitStepPage(limit: 8) { _ in }
        .background(BrandColor.background)
        .preferredColorScheme(.dark)
}
