#if os(iOS)
    import CoreGraphics
    import Testing
    @testable import WorkoutShareUI

    struct ShareCanvasTests {
        /// 칸이 네 개로 고정이라 카드 크기도 하나다. 픽셀이 정수로 떨어져야 반올림 번짐이 없다.
        @Test func cardIsFixedAndPixelsAreWholeNumbers() {
            #expect(ShareCanvas.cardSize == CGSize(width: 270, height: 200))
            #expect(ShareCanvas.cardSize.width * ShareCanvas.scale == 1080)
            #expect(ShareCanvas.cardSize.height * ShareCanvas.scale == 800)
        }
    }
#endif
