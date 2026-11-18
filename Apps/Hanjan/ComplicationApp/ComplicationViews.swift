import SwiftUI
import WidgetKit

struct ComplicationViews: View {
    let snapshot: SessionSnapshot
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    private var fraction: Double {
        min(1, max(0, snapshot.equivalent / max(1, snapshot.limit)))
    }

    private var tint: Color {
        guard renderingMode == .fullColor else { return .primary }
        return LimitLevel.of(equivalent: snapshot.equivalent, limit: snapshot.limit) == .exceeded ? BrandColor.danger : BrandColor.amber
    }

    private var count: String {
        "\(SojuFormat.string(snapshot.equivalent))/\(SojuFormat.string(snapshot.limit))"
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            if snapshot.isActive {
                Text("한잔 · \(count)잔").widgetAccentable()
            } else {
                Image(systemName: "wineglass").widgetAccentable()
            }
        case .accessoryRectangular:
            if snapshot.isActive {
                VStack(alignment: .leading, spacing: 5) {
                    Text("한잔 · \(SojuFormat.string(snapshot.equivalent)) / \(SojuFormat.string(snapshot.limit))잔")
                        .font(.headline).foregroundStyle(tint).widgetAccentable()
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.primary.opacity(0.2))
                            Capsule().fill(tint).frame(width: geometry.size.width * fraction)
                        }
                    }.frame(height: 5)
                }
            } else { Image(systemName: "wineglass").foregroundStyle(tint).widgetAccentable() }
        default:
            if snapshot.isActive {
                ZStack {
                    Circle().stroke(.primary.opacity(0.2), lineWidth: 4)
                    Circle().trim(from: 0, to: fraction).stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
                    Text(count).font(.system(size: 14, weight: .bold, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1).foregroundStyle(tint)
                }.padding(3).widgetAccentable()
            } else { Image(systemName: "wineglass").font(.title2).foregroundStyle(tint).widgetAccentable() }
        }
    }
}

private let previewActive = SessionSnapshot(isActive: true, equivalent: 5, limit: 8, kindName: "소주", updatedAt: Date())
private let previewExceeded = SessionSnapshot(isActive: true, equivalent: 9, limit: 8, kindName: "소주", updatedAt: Date())

#Preview("accessoryCircular 대기", as: .accessoryCircular) { HanjanComplication() } timeline: { HanjanComplicationEntry(date: Date(), snapshot: .idle) }

#Preview("accessoryCircular 진행", as: .accessoryCircular) { HanjanComplication() } timeline: { HanjanComplicationEntry(
    date: Date(),
    snapshot: previewActive
) }

#Preview("accessoryCircular 초과", as: .accessoryCircular) { HanjanComplication() } timeline: { HanjanComplicationEntry(
    date: Date(),
    snapshot: previewExceeded
) }

#Preview("accessoryCorner 대기", as: .accessoryCorner) { HanjanComplication() } timeline: { HanjanComplicationEntry(date: Date(), snapshot: .idle) }

#Preview("accessoryCorner 진행", as: .accessoryCorner) { HanjanComplication() } timeline: { HanjanComplicationEntry(
    date: Date(),
    snapshot: previewActive
) }

#Preview("accessoryCorner 초과", as: .accessoryCorner) { HanjanComplication() } timeline: { HanjanComplicationEntry(
    date: Date(),
    snapshot: previewExceeded
) }

#Preview("accessoryRectangular 대기", as: .accessoryRectangular) { HanjanComplication() } timeline: { HanjanComplicationEntry(
    date: Date(),
    snapshot: .idle
) }

#Preview("accessoryRectangular 진행", as: .accessoryRectangular) { HanjanComplication() } timeline: { HanjanComplicationEntry(
    date: Date(),
    snapshot: previewActive
) }

#Preview("accessoryRectangular 초과", as: .accessoryRectangular) { HanjanComplication() } timeline: { HanjanComplicationEntry(
    date: Date(),
    snapshot: previewExceeded
) }

#Preview("accessoryInline 대기", as: .accessoryInline) { HanjanComplication() } timeline: { HanjanComplicationEntry(date: Date(), snapshot: .idle) }

#Preview("accessoryInline 진행", as: .accessoryInline) { HanjanComplication() } timeline: { HanjanComplicationEntry(
    date: Date(),
    snapshot: previewActive
) }

#Preview("accessoryInline 초과", as: .accessoryInline) { HanjanComplication() } timeline: { HanjanComplicationEntry(
    date: Date(),
    snapshot: previewExceeded
) }
