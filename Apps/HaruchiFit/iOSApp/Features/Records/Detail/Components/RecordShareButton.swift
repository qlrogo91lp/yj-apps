import SwiftUI
import WorkoutShareUI

struct RecordShareButton: View {
    let content: RecordShareContent

    var body: some View {
        WorkoutShareButton(
            result: content.result,
            header: WorkoutShareHeader(title: content.title,
                                       startedAt: content.startedAt,
                                       endedAt: content.endedAt),
            style: WorkoutShareStyle(badgeColor: HaruchiPalette.accent,
                                     logo: Image("HaruchiLogo")),
            accessory: content.composition.map { ShareComposition(composition: $0) }
        )
    }
}
