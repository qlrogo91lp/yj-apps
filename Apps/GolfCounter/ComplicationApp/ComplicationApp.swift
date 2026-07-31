import SwiftUI
import WidgetKit

struct ComplicationEntry: TimelineEntry {
    let date: Date
}

struct Provider: TimelineProvider {
    func placeholder(in _: Context) -> ComplicationEntry {
        ComplicationEntry(date: Date())
    }

    func getSnapshot(in _: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(ComplicationEntry(date: Date()))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        completion(Timeline(entries: [ComplicationEntry(date: Date())], policy: .never))
    }
}

struct ComplicationAppEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        Image(systemName: "figure.golf")
    }
}

struct ComplicationApp: Widget {
    let kind: String = "ComplicationApp"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ComplicationAppEntryView(entry: entry)
                .containerBackground(.green, for: .widget)
        }
        .configurationDisplayName("GolfCounter")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular])
    }
}
