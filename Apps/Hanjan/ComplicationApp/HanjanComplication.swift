import SwiftUI
import WidgetKit

struct HanjanComplicationEntry: TimelineEntry {
    let date: Date
    let snapshot: SessionSnapshot
}

struct HanjanComplicationProvider: TimelineProvider {
    func placeholder(in _: Context) -> HanjanComplicationEntry {
        HanjanComplicationEntry(date: Date(), snapshot: .idle)
    }

    func getSnapshot(in _: Context, completion: @escaping (HanjanComplicationEntry) -> Void) {
        completion(current())
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<HanjanComplicationEntry>) -> Void) {
        completion(Timeline(entries: [current()], policy: .never))
    }

    private func current() -> HanjanComplicationEntry {
        HanjanComplicationEntry(date: Date(), snapshot: SessionSnapshotStore.read())
    }
}

struct HanjanComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HanjanComplication", provider: HanjanComplicationProvider()) { entry in
            ComplicationViews(snapshot: entry.snapshot).containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("한잔")
        .description("현재 술자리의 잔 수를 확인합니다.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}
