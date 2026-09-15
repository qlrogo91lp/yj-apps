#if os(iOS)
    import os
    import SwiftUI
    import UIKit

    /// 카드 모서리를 어떻게 구울지 — 이미지를 받는 곳이 투명을 다루는 방식이 달라서 경로마다 고른다.
    enum ShareCardCorners {
        /// 둥근 모서리 + 바깥 투명. 인스타 스토리 **스티커층**은 투명을 그대로 붙인다.
        case rounded
        /// 모서리를 자르지 않은 불투명 네모. 인스타는 공유 시트로 받은 사진의 투명을 **검정으로 채워**
        /// 둥근 카드의 모서리가 검게 떴다 (실기기). 메시지·사진 저장도 투명을 보장하지 않는다.
        case square
    }

    /// 카드 뷰를 이미지로 굽는다. 탭 시점에 한 장만 만든다.
    @MainActor
    enum WorkoutShareRenderer {
        private static let logger = Logger(subsystem: "com.yj.YJKit", category: "WorkoutShareUI")

        static func image(model: WorkoutShareCardModel,
                          style: WorkoutShareStyle,
                          corners: ShareCardCorners = .rounded) -> UIImage?
        {
            let renderer = ImageRenderer(content: WorkoutShareCard(model: model, style: style, corners: corners))
            renderer.scale = ShareCanvas.scale
            // 둥근 모서리 바깥을 투명하게 남기려면 불투명 렌더를 꺼야 한다 — 켜면 모서리가 검게 찬다.
            renderer.isOpaque = corners == .square
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
