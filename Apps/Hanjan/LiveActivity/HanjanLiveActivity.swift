import ActivityKit
import SwiftUI
import WidgetKit

struct HanjanLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HanjanActivityAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(BrandColor.background)
                .activitySystemActionForegroundColor(BrandColor.amber)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { Text("한잔 · \(context.state.kindName)").font(.headline) }
                DynamicIslandExpandedRegion(.trailing) { IslandCount(state: context.state) }
                DynamicIslandExpandedRegion(.bottom) { IslandExpandedView(state: context.state) }
            } compactLeading: {
                Image(systemName: "wineglass")
            } compactTrailing: {
                IslandCount(state: context.state)
            } minimal: {
                Image(systemName: "wineglass")
            }
            .keylineTint(LimitLevel.of(equivalent: context.state.equivalent, limit: context.state.limit) == .exceeded ? BrandColor
                .danger : BrandColor.amber)
        }
    }
}

#Preview("진행", as: .content, using: HanjanActivityAttributes(sessionId: UUID())) {
    HanjanLiveActivity()
} contentStates: {
    HanjanActivityAttributes.ContentState(kindName: "소주", equivalent: 5, limit: 8, toastFilled: 1, toastTotal: 3, toastOnly: true)
}

#Preview("초과", as: .content, using: HanjanActivityAttributes(sessionId: UUID())) {
    HanjanLiveActivity()
} contentStates: {
    HanjanActivityAttributes.ContentState(kindName: "소주", equivalent: 9, limit: 8, toastFilled: nil, toastTotal: nil, toastOnly: false)
}
