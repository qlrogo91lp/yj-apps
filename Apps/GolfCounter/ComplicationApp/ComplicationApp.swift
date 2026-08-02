import SwiftUI
import WidgetKit

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let state: ComplicationState
}

struct Provider: TimelineProvider {
    func placeholder(in _: Context) -> ComplicationEntry {
        ComplicationEntry(date: Date(), state: ComplicationState(snapshot: nil))
    }

    func getSnapshot(in _: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(currentEntry())
    }

    /// 시간 기반 갱신이 필요 없다 — 라운드 상태가 바뀔 때 워치 앱이 reloadAllTimelines()를 호출한다 (plan ③).
    func getTimeline(in _: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> ComplicationEntry {
        ComplicationEntry(date: Date(), state: ComplicationState(snapshot: RoundSnapshotStore.load()))
    }
}

struct ComplicationAppEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    var entry: ComplicationEntry

    var body: some View {
        switch widgetFamily {
        case .accessoryRectangular:
            rectangularBody
                .containerBackground(.clear, for: .widget)
        default:
            iconBody
                .containerBackground(entry.state.isRoundActive ? Color.brandActive : Color.brand, for: .widget)
        }
    }

    private var iconBody: some View {
        golfIcon
            .padding(4)
    }

    private var rectangularBody: some View {
        HStack(spacing: 8) {
            golfIcon
                .frame(width: 24, height: 24)
            if entry.state.isRoundActive {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(entry.state.holeText) · \(entry.state.relativeToParText)")
                        .font(.headline)
                    Text(entry.state.strokesText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("라운드 시작")
                    .font(.headline)
            }
            Spacer(minLength: 0)
        }
    }

    private var golfIcon: some View {
        Image("GolfIcon")
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
    }
}

struct ComplicationApp: Widget {
    let kind: String = "ComplicationApp"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ComplicationAppEntryView(entry: entry)
        }
        .configurationDisplayName("GolfCounter")
        .description("라운드 진행 상황")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular])
    }
}

private func previewSnapshot() -> RoundSnapshot {
    RoundSnapshot(startedAt: Date(),
                  courseName: "테스트CC",
                  currentHoleIndex: 6,
                  holeScores: [4, 3, 6, 5, 4, 3, 2],
                  holePars: [4, 3, 5, 4, 4, 3, 4],
                  puttCounts: [2, 1, 2, 2, 1, 1, 1])
}

#Preview(as: .accessoryCircular) {
    ComplicationApp()
} timeline: {
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: nil))
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: previewSnapshot()))
}

#Preview(as: .accessoryRectangular) {
    ComplicationApp()
} timeline: {
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: nil))
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: previewSnapshot()))
}
