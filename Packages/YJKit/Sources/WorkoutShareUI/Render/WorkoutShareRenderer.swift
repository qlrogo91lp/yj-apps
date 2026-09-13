#if os(iOS)
    import os
    import SwiftUI
    import UIKit

    /// 카드 뷰를 이미지로 굽는다. 탭 시점에 한 장만 만든다.
    @MainActor
    enum WorkoutShareRenderer {
        private static let logger = Logger(subsystem: "com.yj.YJKit", category: "WorkoutShareUI")

        static func image(model: WorkoutShareCardModel,
                          style: WorkoutShareStyle) -> UIImage?
        {
            let renderer = ImageRenderer(content: WorkoutShareCard(model: model, style: style))
            renderer.scale = ShareCanvas.scale
            renderer.isOpaque = true
            guard let image = renderer.uiImage else {
                // 조용히 실패하면 사용자는 버튼이 고장난 줄 안다.
                logger.error("공유 카드 렌더에 실패했다")
                assertionFailure("공유 카드 렌더에 실패했다")
                return nil
            }
            return image
        }
    }
#endif
