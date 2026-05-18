import SwiftUI
import WidgetKit

private let appGroupID = "group.com.yj.TennisCounter"
private let workoutActiveKey = "isWorkoutActive"
private let rotationFrameCount = 8      // 45° 간격
private let rotationFrameInterval = 2.0 // 초 단위, 한 프레임 지속 시간
private let rotationBatchSize = 80      // 한 번에 생성할 entries 수 (~160초)

struct Provider: TimelineProvider {
    func placeholder(in _: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), isWorkoutActive: false, rotationDegrees: 0, scaleFactor: 1.0)
    }

    func getSnapshot(in _: Context, completion: @escaping (SimpleEntry) -> Void) {
        let isActive = UserDefaults(suiteName: appGroupID)?.bool(forKey: workoutActiveKey) ?? false
        completion(SimpleEntry(date: Date(), isWorkoutActive: isActive, rotationDegrees: 0, scaleFactor: 1.0))
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let isActive = UserDefaults(suiteName: appGroupID)?.bool(forKey: workoutActiveKey) ?? false

        if isActive {
            let startDate = Date()
            let degreesPerFrame = 360.0 / Double(rotationFrameCount)
            let entries: [SimpleEntry] = (0..<rotationBatchSize).map { i in
                let degrees = Double(i % rotationFrameCount) * degreesPerFrame
                let scale = i % 2 == 0 ? 1.0 : 0.85
                let entryDate = startDate.addingTimeInterval(Double(i) * rotationFrameInterval)
                return SimpleEntry(date: entryDate, isWorkoutActive: true, rotationDegrees: degrees, scaleFactor: scale)
            }
            let reloadDate = startDate.addingTimeInterval(Double(rotationBatchSize) * rotationFrameInterval)
            completion(Timeline(entries: entries, policy: .after(reloadDate)))
        } else {
            let entry = SimpleEntry(date: Date(), isWorkoutActive: false, rotationDegrees: 0, scaleFactor: 1.0)
            completion(Timeline(entries: [entry], policy: .never))
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let isWorkoutActive: Bool
    let rotationDegrees: Double
    let scaleFactor: Double
}

struct ComplicationAppEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: Provider.Entry

    private let bgColor = Color(red: 0.6784, green: 1.0, blue: 0.2549)

    var body: some View {
        switch widgetFamily {
        case .accessoryCorner:
            ZStack {
                bgColor
                iconImage
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
            }
            .rotationEffect(.degrees(entry.rotationDegrees))
            .scaleEffect(entry.scaleFactor)
        default:
            ZStack {
                bgColor
                iconImage
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .padding(4)
                    .rotationEffect(.degrees(entry.rotationDegrees))
                    .scaleEffect(entry.scaleFactor)
            }
            .clipShape(Circle())
        }
    }

    private var iconImage: Image {
        Image("RalliIcon")
    }
}

struct ComplicationApp: Widget {
    let kind: String = "ComplicationApp"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(watchOS 10.0, *) {
                ComplicationAppEntryView(entry: entry)
                    .containerBackground(Color(red: 0.6784, green: 1.0, blue: 0.2549), for: .widget)
            } else {
                ComplicationAppEntryView(entry: entry)
                    .background(Color(red: 0.6784, green: 1.0, blue: 0.2549))
            }
        }
        .configurationDisplayName("Ralli")
        .description("Tennis Counter")
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}

#Preview(as: .accessoryCircular) {
    ComplicationApp()
} timeline: {
    SimpleEntry(date: .now, isWorkoutActive: false, rotationDegrees: 0, scaleFactor: 1.0)
    SimpleEntry(date: .now, isWorkoutActive: true, rotationDegrees: 0, scaleFactor: 1.0)
    SimpleEntry(date: .now, isWorkoutActive: true, rotationDegrees: 45, scaleFactor: 0.85)
    SimpleEntry(date: .now, isWorkoutActive: true, rotationDegrees: 90, scaleFactor: 1.0)
}

#Preview(as: .accessoryCorner) {
    ComplicationApp()
} timeline: {
    SimpleEntry(date: .now, isWorkoutActive: false, rotationDegrees: 0, scaleFactor: 1.0)
    SimpleEntry(date: .now, isWorkoutActive: true, rotationDegrees: 45, scaleFactor: 0.85)
}
