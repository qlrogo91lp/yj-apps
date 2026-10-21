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

        /// 자리를 안 쓰는 앱(Ralli)의 카드는 예전과 같다.
        @Test func noAccessoryKeepsOriginalSize() {
            #expect(ShareCanvas.cardSize(hasAccessory: false) == CGSize(width: 270, height: 200))
            #expect(ShareCanvas.cardSize(hasAccessory: false) == ShareCanvas.cardSize)
        }

        /// 자리가 있으면 카드가 그만큼 높아지고, 기록마다 크기가 달라지지 않게 하나로 고정이다.
        @Test func accessoryCardIsTallerAndWholePixels() {
            let size = ShareCanvas.cardSize(hasAccessory: true)
            #expect(size.width == 270)
            #expect(size.height > 200)
            #expect((size.height * ShareCanvas.scale).truncatingRemainder(dividingBy: 1) == 0)
        }

        /// 자리는 카드 좌우 패딩(18) 안쪽 폭이다.
        @Test func accessoryFitsInsideCardPadding() {
            let expected: CGFloat = 234
            #expect(ShareCanvas.accessorySize.width == expected)
        }
    }
#endif
