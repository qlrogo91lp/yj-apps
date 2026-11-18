import SwiftUI
import WorkoutShareUI

struct RecordShareButton: View {
    let content: RecordShareContent

    private static func header(_ content: RecordShareContent) -> WorkoutShareHeader {
        WorkoutShareHeader(title: content.title, startedAt: content.startedAt, endedAt: content.endedAt)
    }

    private static var style: WorkoutShareStyle {
        WorkoutShareStyle(badgeColor: HaruchiPalette.accent, logo: Image("HaruchiLogo"))
    }

    @MainActor
    static func copySticker(content: RecordShareContent) -> Bool {
        WorkoutShareExport.copySticker(result: content.result, header: header(content), style: style,
                                       accessory: content.composition.map { ShareComposition(composition: $0) })
    }

    var body: some View {
        WorkoutShareButton(
            result: content.result,
            header: Self.header(content),
            style: Self.style,
            accessory: content.composition.map { ShareComposition(composition: $0) }
        )
    }
}
