#if os(iOS)
    import CoreGraphics
    import Testing
    @testable import WorkoutShareUI

    struct ShareCanvasTests {
        @Test func stickerHeightMatchesTheSpecTable() {
            #expect(ShareCanvas.stickerSize(rowCount: 3, hasLogo: true)
                == CGSize(width: 270, height: 190))
            #expect(ShareCanvas.stickerSize(rowCount: 2, hasLogo: true)
                == CGSize(width: 270, height: 148))
            #expect(ShareCanvas.stickerSize(rowCount: 1, hasLogo: true)
                == CGSize(width: 270, height: 106))
        }

        @Test func droppingLogoRemovesTheStripHeight() {
            #expect(ShareCanvas.stickerSize(rowCount: 3, hasLogo: false).height == 158)
            #expect(ShareCanvas.stickerSize(rowCount: 1, hasLogo: false).height == 74)
        }

        @Test func scaledStickerPixelsAreWholeNumbers() {
            let size = ShareCanvas.stickerSize(rowCount: 3, hasLogo: true)
            #expect(size.width * ShareCanvas.scale == 1080)
            #expect(size.height * ShareCanvas.scale == 760)
        }

        @Test func standaloneCanvasIsStorySize() {
            #expect(ShareCanvas.standaloneSize.width * ShareCanvas.scale == 1080)
            #expect(ShareCanvas.standaloneSize.height * ShareCanvas.scale == 1920)
        }

        /// 스토리 안전 영역은 1080×1330 px = 270×332.5 pt다. 가장 큰 카드가 그 안에 들어가야
        /// 인스타그램 UI에 가리지 않는다.
        @Test func tallestStickerFitsInsideTheStorySafeArea() {
            #expect(ShareCanvas.stickerSize(rowCount: 3, hasLogo: true).height <= 332.5)
        }
    }
#endif
