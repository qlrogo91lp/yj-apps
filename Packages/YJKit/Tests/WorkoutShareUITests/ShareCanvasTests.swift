#if os(iOS)
    import CoreGraphics
    import Testing
    @testable import WorkoutShareUI

    struct ShareCanvasTests {
        @Test func cardHeightMatchesTheSpecTable() {
            #expect(ShareCanvas.cardSize(rowCount: 3, hasLogo: true)
                == CGSize(width: 270, height: 190))
            #expect(ShareCanvas.cardSize(rowCount: 2, hasLogo: true)
                == CGSize(width: 270, height: 148))
            #expect(ShareCanvas.cardSize(rowCount: 1, hasLogo: true)
                == CGSize(width: 270, height: 106))
        }

        @Test func droppingLogoRemovesTheStripHeight() {
            #expect(ShareCanvas.cardSize(rowCount: 3, hasLogo: false).height == 158)
            #expect(ShareCanvas.cardSize(rowCount: 1, hasLogo: false).height == 74)
        }

        @Test func scaledCardPixelsAreWholeNumbers() {
            let size = ShareCanvas.cardSize(rowCount: 3, hasLogo: true)
            #expect(size.width * ShareCanvas.scale == 1080)
            #expect(size.height * ShareCanvas.scale == 760)
        }

        @Test func imageCanvasIsStorySize() {
            #expect(ShareCanvas.imageSize.width * ShareCanvas.scale == 1080)
            #expect(ShareCanvas.imageSize.height * ShareCanvas.scale == 1920)
        }

        @Test func tallestCardFitsInsideTheImage() {
            #expect(ShareCanvas.cardSize(rowCount: 3, hasLogo: true).height <= ShareCanvas.imageHeight)
        }
    }
#endif
