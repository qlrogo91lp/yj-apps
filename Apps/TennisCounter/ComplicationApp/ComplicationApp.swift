//
//  ComplicationApp.swift
//  ComplicationApp
//
//  Created by 윤재 on 11/6/25.
//

import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        completion(SimpleEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = SimpleEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct ComplicationAppEntryView : View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: Provider.Entry

    var body: some View {
        switch widgetFamily {
        case .accessoryCorner:
            Image("AppIcon")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
        case .accessoryRectangular:
            HStack(spacing: 6) {
                Image("AppIcon")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                Text("Tennis Counter")
                    .font(.headline)
                    .widgetAccentable()
            }
        default:
            Image("AppIcon")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .padding(6)
                .clipShape(Circle())
        }
    }
}

struct ComplicationApp: Widget {
    let kind: String = "ComplicationApp"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(watchOS 10.0, *) {
                ComplicationAppEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                ComplicationAppEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Tennis Counter")
        .description("Tennis score counter complication.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular])
    }
}

#Preview(as: .accessoryCircular) {
    ComplicationApp()
} timeline: {
    SimpleEntry(date: .now)
}

#Preview(as: .accessoryRectangular) {
    ComplicationApp()
} timeline: {
    SimpleEntry(date: .now)
}

#Preview(as: .accessoryCorner) {
    ComplicationApp()
} timeline: {
    SimpleEntry(date: .now)
}
