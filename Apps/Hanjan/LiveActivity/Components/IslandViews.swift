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
            if state.toastOnly {
                Button(intent: AddDrinkIntent()) { Text("짠만").padding(.horizontal, 10).padding(.vertical, 6) }
                    .buttonStyle(.plain).foregroundStyle(BrandColor.amber).overlay(Capsule().stroke(BrandColor.amber))
            } else {
                Button(intent: AddDrinkIntent()) { Text("한 잔") }
                    .buttonStyle(.borderedProminent)
                    .tint(LimitLevel.of(equivalent: state.equivalent, limit: state.limit) == .exceeded ? BrandColor.danger : BrandColor.amber)
                    .foregroundStyle(.black)
            }
        }
    }
}

#Preview { IslandExpandedView(state: .init(kindName: "소주", equivalent: 5, limit: 8, toastFilled: nil, toastTotal: nil, toastOnly: false)) }
