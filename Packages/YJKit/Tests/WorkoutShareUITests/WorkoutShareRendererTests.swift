#if os(iOS)
    import SwiftUI
    import Testing
    import WorkoutCore
    @testable import WorkoutShareUI

    @MainActor
    struct WorkoutShareRendererTests {
        private let style = WorkoutShareStyle(accentColor: .green)

        @Test func imageRendersAtStorySize() {
            let model = WorkoutShareCardModel(result: WorkoutResult(durationSeconds: 2538,
                                                                   caloriesBurned: 312,
                                                                   averageHeartRate: 148))
            let image = WorkoutShareRenderer.image(model: model, style: style)
            #expect(image?.cgImage?.width == 1080)
            #expect(image?.cgImage?.height == 1920)
        }

        /// 행이 줄어도 카드만 줄고 이미지 크기는 그대로다.
        @Test func fewerRowsKeepStorySize() {
            let model = WorkoutShareCardModel(result: WorkoutResult(durationSeconds: 600,
                                                                   caloriesBurned: 0,
                                                                   averageHeartRate: nil))
            let image = WorkoutShareRenderer.image(model: model, style: style)
            #expect(image?.cgImage?.height == 1920)
        }
    }
#endif
