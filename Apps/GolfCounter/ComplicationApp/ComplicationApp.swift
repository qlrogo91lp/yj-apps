import SwiftUI
import WidgetKit

private let rotationFrameCount = 8 // 45° 간격
private let rotationFrameInterval = 4.0 // 초 단위, 한 프레임 지속 시간
private let rotationBatchSize = 80 // 한 번에 생성할 entries 수 (~320초)

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let state: ComplicationState
    let rotationDegrees: Double
}

struct Provider: TimelineProvider {
    func placeholder(in _: Context) -> ComplicationEntry {
        ComplicationEntry(date: Date(), state: ComplicationState(snapshot: nil), rotationDegrees: 0)
    }

    func getSnapshot(in _: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(currentEntry())
    }

    /// 라운드 비활성 시엔 시간 기반 갱신이 필요 없다 — 상태가 바뀔 때 워치 앱이 reloadAllTimelines()를 호출한다 (plan ③).
    /// 라운드 활성 시엔 Ralli(tennis_counter)와 동일하게 회전 애니메이션 엔트리를 배치 생성한다.
    func getTimeline(in _: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let state = ComplicationState(snapshot: RoundSnapshotStore.load())

        if state.isRoundActive {
            let startDate = Date()
            let degreesPerFrame = 360.0 / Double(rotationFrameCount)
            let entries: [ComplicationEntry] = (0 ..< rotationBatchSize).map { i in
                let degrees = Double(i % rotationFrameCount) * degreesPerFrame
                let entryDate = startDate.addingTimeInterval(Double(i) * rotationFrameInterval)
                return ComplicationEntry(date: entryDate, state: state, rotationDegrees: degrees)
            }
            let reloadDate = startDate.addingTimeInterval(Double(rotationBatchSize) * rotationFrameInterval)
            completion(Timeline(entries: entries, policy: .after(reloadDate)))
        } else {
            completion(Timeline(entries: [currentEntry()], policy: .never))
        }
    }

    private func currentEntry() -> ComplicationEntry {
        ComplicationEntry(date: Date(), state: ComplicationState(snapshot: RoundSnapshotStore.load()), rotationDegrees: 0)
    }
}

struct ComplicationAppEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    @Environment(\.widgetRenderingMode) private var renderingMode
    var entry: ComplicationEntry

    private var backgroundColor: Color {
        entry.state.isRoundActive ? .brandActive : .brand
    }

    var body: some View {
        switch widgetFamily {
        case .accessoryRectangular:
            rectangularBody
                .containerBackground(.clear, for: .widget)
        case .accessoryCorner:
            cornerBody
                .containerBackground(backgroundColor, for: .widget)
        default:
            circularBody
                .clipShape(Circle())
                .containerBackground(backgroundColor, for: .widget)
        }
    }

    /// corner는 배경+아이콘을 통째로 회전 (Ralli와 동일 구조).
    private var cornerBody: some View {
        ZStack {
            if renderingMode == .fullColor {
                backgroundColor
            }
            golfIcon(templated: entry.state.isRoundActive)
                .padding(4)
                .widgetAccentable()
        }
        .rotationEffect(.degrees(entry.rotationDegrees))
    }

    /// circular은 아이콘만 회전한 뒤 원형으로 클리핑 (Ralli와 동일 구조).
    private var circularBody: some View {
        ZStack {
            if renderingMode == .fullColor {
                backgroundColor
            }
            golfIcon(templated: entry.state.isRoundActive)
                .padding(4)
                .rotationEffect(.degrees(entry.rotationDegrees))
                .widgetAccentable()
        }
    }

    private var rectangularBody: some View {
        HStack(spacing: 8) {
            golfIcon(templated: false)
                .frame(width: 24, height: 24)
            if entry.state.isRoundActive {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(entry.state.holeText) · \(entry.state.relativeToParText)")
                        .font(.headline)
                    Text(String(format: String(localized: "complication_strokes"),
                                entry.state.totalStrokes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(String(localized: "complication_start_round"))
                    .font(.headline)
            }
            Spacer(minLength: 0)
        }
    }

    /// 라운드 활성 중엔 노란 배경과 대비되도록 검정 템플릿으로 렌더링 (Ralli 아이콘과 동일한 대비).
    @ViewBuilder
    private func golfIcon(templated: Bool) -> some View {
        if templated {
            Image("GolfIcon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.black)
        } else {
            Image("GolfIcon")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
        }
    }
}

struct ComplicationApp: Widget {
    let kind: String = "ComplicationApp"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ComplicationAppEntryView(entry: entry)
        }
        .configurationDisplayName("GolfCounter")
        .description(String(localized: "complication_description"))
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
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: nil), rotationDegrees: 0)
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: previewSnapshot()), rotationDegrees: 0)
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: previewSnapshot()), rotationDegrees: 45)
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: previewSnapshot()), rotationDegrees: 90)
}

#Preview(as: .accessoryCorner) {
    ComplicationApp()
} timeline: {
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: nil), rotationDegrees: 0)
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: previewSnapshot()), rotationDegrees: 0)
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: previewSnapshot()), rotationDegrees: 45)
}

#Preview(as: .accessoryRectangular) {
    ComplicationApp()
} timeline: {
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: nil), rotationDegrees: 0)
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: previewSnapshot()), rotationDegrees: 0)
}
