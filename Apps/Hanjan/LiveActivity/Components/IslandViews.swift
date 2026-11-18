import AppIntents
import SwiftUI

struct IslandCount: View {
    let state: HanjanActivityAttributes.ContentState
    var body: some View {
        Text("\(SojuFormat.string(state.equivalent))/\(SojuFormat.string(state.limit))")
            .foregroundStyle(LimitLevel.of(equivalent: state.equivalent, limit: state.limit) == .exceeded ? BrandColor.danger : BrandColor.amber)
    }
}

struct IslandExpandedView: View {
    let state: HanjanActivityAttributes.ContentState
    var body: some View {
        HStack {
            ProgressView(value: min(state.equivalent / max(state.limit, 1), 1))
                .tint(LimitLevel.of(equivalent: state.equivalent, limit: state.limit) == .exceeded ? BrandColor.danger : BrandColor.amber)
            Button(intent: AddDrinkIntent()) {
                Text(state.toastOnly ? "짠만" : "한 잔").frame(width: 54, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(state.toastOnly ? BrandColor.amber : Color.black)
            .background(state.toastOnly ? BrandColor.amber.opacity(0.2) :
                (LimitLevel.of(equivalent: state.equivalent, limit: state.limit) == .exceeded ? BrandColor.danger : BrandColor.amber), in: Capsule())
        }
    }
}

#Preview { IslandExpandedView(state: .init(kindName: "소주", equivalent: 5, limit: 8, toastFilled: nil, toastTotal: nil, toastOnly: false)) }
