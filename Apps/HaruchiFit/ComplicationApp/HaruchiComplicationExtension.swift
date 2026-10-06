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

    /// 대기 중에도 배경을 채운다 — 비워 두면 검은 워치 페이스에서 영역이 안 보인다 (골프·Ralli 와 같다).
    /// 대기는 회색 판에 오렌지 로고, 진행 중은 유형 색 판에 검정 로고.
    private var backgroundColor: Color {
        entry.state.isActive ? tint : Color(white: 0.12)
    }

    /// `containerBackground` 는 선택 화면·로딩에서만 보이고 실제 페이스에선 안 그려지는 경우가 많아,
    /// 풀컬러일 때 같은 색을 `ZStack` 안에 한 번 더 깐다. 틴트 페이스에선 배경을 빼고 로고만 페이스 색을 따른다.
    var body: some View {
        switch widgetFamily {
        case .accessoryRectangular:
            rectangularBody
                .containerBackground(.clear, for: .widget)
        case .accessoryCorner:
            badgeBody
                .containerBackground(backgroundColor, for: .widget)
        default:
            badgeBody
                .clipShape(Circle())
                .containerBackground(backgroundColor, for: .widget)
        }
    }

    /// 원형·코너 공용.
    private var badgeBody: some View {
        ZStack {
            if renderingMode == .fullColor {
                backgroundColor
            }
            icon
                .foregroundStyle(entry.state.isActive ? Color.black : .brandOrange)
                .scaleEffect(0.6)
                .widgetAccentable()
        }
    }

    private var rectangularBody: some View {
        HStack(spacing: 8) {
            icon
                .foregroundStyle(entry.state.isActive ? tint : .brandOrange)
                .frame(width: 24, height: 24)
                .widgetAccentable()

            if entry.state.isActive {
                VStack(alignment: .leading, spacing: 0) {
                    elapsed
                        .font(.headline)
                        .widgetAccentable()
                    Text(entry.state.mode.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("운동 시작")
                    .font(.headline)
                    .widgetAccentable()
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

    /// 앱 아이콘과 같은 로고(`HaruchiIcon`)를 템플릿으로 쓴다. 색은 호출부가 정한다.
    private var icon: some View {
        Image("HaruchiIcon")
            .resizable()
            .scaledToFit()
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
