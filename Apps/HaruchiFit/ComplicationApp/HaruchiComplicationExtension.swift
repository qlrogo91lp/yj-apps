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
    var entry: ComplicationEntry

    /// 유형 구분은 색으로만 한다 — W0 홈 토글과 같은 규칙이다 (근력 오렌지 · 유산소 파랑).
    private var tint: Color {
        entry.state.mode == .cardio ? .blue : .brandOrange
    }

    /// 대기 중엔 시스템 반투명 판을 깐다 — 검은 워치 페이스에서도 영역이 보이고 틴트 페이스에도 맞는다.
    /// 진행 중 원형·코너는 유형 색으로 채워 "운동 중" 신호를 남긴다.
    @ViewBuilder
    private var badgeBackground: some View {
        if entry.state.isActive {
            tint
        } else {
            AccessoryWidgetBackground()
        }
    }

    var body: some View {
        switch widgetFamily {
        case .accessoryRectangular:
            rectangularBody
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        default:
            badgeBody
                .containerBackground(for: .widget) { badgeBackground }
        }
    }

    /// 원형·코너 공용.
    private var badgeBody: some View {
        icon(active: .black)
            .padding(4)
            .widgetAccentable()
    }

    private var rectangularBody: some View {
        HStack(spacing: 8) {
            icon(active: tint)
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

    /// 앱 아이콘과 같은 로고(`HaruchiIcon`)를 템플릿으로 쓴다. 근력·유산소 구분은 색이 한다.
    /// 진행 중 색은 배경에 따라 달라 호출부가 정한다 — 색 배경 위에선 검정, 반투명 판 위에선 유형 색.
    private func icon(active: Color) -> some View {
        Image("HaruchiIcon")
            .resizable()
            .scaledToFit()
            .foregroundStyle(entry.state.isActive ? active : .brandOrange)
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
