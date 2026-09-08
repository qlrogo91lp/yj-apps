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

    /// **정책은 언제나 `.never` 다.** 진행 중이어도 엔트리를 배치로 만들지 않는다 —
    /// 경과시간은 `Text(_:style: .timer)` 가 스스로 흘려주고, 상태가 바뀌면 워치 앱이
    /// `reloadAllTimelines()` 를 부른다. 그게 갱신의 유일한 트리거다 (제품 스펙 WC절).
    func getTimeline(in _: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    /// 컴플리케이션은 **HealthKit 을 보지 않는다** (D-M4). 워치 앱이 App Group 에 남긴
    /// 스냅샷만 읽는다.
    private func currentEntry() -> ComplicationEntry {
        ComplicationEntry(date: Date(), state: ComplicationState(snapshot: WorkoutSnapshotStore.load()))
    }
}

struct HaruchiComplicationEntryView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    @Environment(\.widgetRenderingMode) private var renderingMode
    var entry: ComplicationEntry

    /// 유형 구분은 색으로만 한다 — W0 홈 토글과 같은 규칙이다 (근력 오렌지 · 유산소 파랑).
    private var tint: Color {
        entry.state.mode == .cardio ? .blue : .brandOrange
    }

    private var background: Color {
        entry.state.isActive ? tint : .clear
    }

    var body: some View {
        switch widgetFamily {
        case .accessoryRectangular:
            rectangularBody
                .containerBackground(.clear, for: .widget)
        case .accessoryCorner:
            cornerBody
                .containerBackground(background, for: .widget)
        default:
            circularBody
                .containerBackground(background, for: .widget)
        }
    }

    private var circularBody: some View {
        ZStack {
            if renderingMode == .fullColor, entry.state.isActive {
                background
            }
            icon
                .padding(4)
                .widgetAccentable()
        }
    }

    private var cornerBody: some View {
        ZStack {
            if renderingMode == .fullColor, entry.state.isActive {
                background
            }
            icon
                .padding(4)
                .widgetAccentable()
        }
    }

    private var rectangularBody: some View {
        HStack(spacing: 8) {
            icon
                .frame(width: 24, height: 24)

            if entry.state.isActive {
                VStack(alignment: .leading, spacing: 0) {
                    elapsed
                        .font(.headline)
                    Text(entry.state.mode.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("운동 시작")
                    .font(.headline)
            }

            Spacer(minLength: 0)
        }
    }

    /// 정지 중에는 타이머를 태울 수 없다 — 멈춘 채로 흐르는 숫자만큼 나쁜 표시가 없다.
    @ViewBuilder
    private var elapsed: some View {
        if entry.state.isPaused {
            Text(entry.state.elapsedText)
        } else if let reference = entry.state.timerReference {
            Text(reference, style: .timer)
        }
    }

    /// 골프는 전용 `GolfIcon` 애셋을 쓴다. 하루치엔 아직 그 애셋이 없어 SF Symbol 로 둔다 —
    /// 아이콘을 그리면 여기만 바꾸면 된다.
    private var icon: some View {
        Image(systemName: entry.state.isActive
            ? (entry.state.mode == .cardio ? "figure.run" : "figure.strengthtraining.traditional")
            : "flame.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(entry.state.isActive ? .black : Color.brandOrange)
    }
}

struct HaruchiComplicationExtension: Widget {
    let kind: String = "HaruchiComplicationExtension"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            HaruchiComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("하루치 핏")
        .description("진행 중인 운동을 보여줍니다.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular])
    }
}

private func previewSnapshot(mode: SegmentKind = .strength, isPaused: Bool = false) -> WorkoutSnapshot {
    WorkoutSnapshot(startedAt: Date().addingTimeInterval(-754),
                    mode: mode,
                    isPaused: isPaused,
                    elapsedSeconds: 754,
                    capturedAt: Date())
}

#Preview(as: .accessoryRectangular) {
    HaruchiComplicationExtension()
} timeline: {
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: nil))
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: previewSnapshot()))
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: previewSnapshot(mode: .cardio)))
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: previewSnapshot(isPaused: true)))
}

#Preview(as: .accessoryCircular) {
    HaruchiComplicationExtension()
} timeline: {
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: nil))
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: previewSnapshot()))
    ComplicationEntry(date: .now, state: ComplicationState(snapshot: previewSnapshot(mode: .cardio)))
}
