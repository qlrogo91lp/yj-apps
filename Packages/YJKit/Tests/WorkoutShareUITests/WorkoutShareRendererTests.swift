#if os(iOS)
    import CoreGraphics
    import SwiftUI
    import Testing
    import UIKit
    import WorkoutCore
    @testable import WorkoutShareUI

    @MainActor
    struct WorkoutShareRendererTests {
        private let style = WorkoutShareStyle(accentColor: .green)

        private var threeRowModel: WorkoutShareCardModel {
            WorkoutShareCardModel(result: WorkoutResult(durationSeconds: 2538,
                                                       caloriesBurned: 312,
                                                       averageHeartRate: 148))
        }

        /// 로고가 없으므로 3행 캔버스는 158pt = 632px다.
        @Test func stickerRendersAtFourTimesTheCanvas() {
            let image = WorkoutShareRenderer.stickerImage(model: threeRowModel, style: style)
            #expect(image?.cgImage?.width == 1080)
            #expect(image?.cgImage?.height == 632)
        }

        @Test func fewerRowsProduceAShorterSticker() {
            let oneRow = WorkoutShareCardModel(result: WorkoutResult(durationSeconds: 600,
                                                                    caloriesBurned: 0,
                                                                    averageHeartRate: nil))
            let image = WorkoutShareRenderer.stickerImage(model: oneRow, style: style)
            #expect(image?.cgImage?.height == 296)
        }

        @Test func standaloneRendersAtStorySize() {
            let image = WorkoutShareRenderer.standaloneImage(model: threeRowModel, style: style)
            #expect(image?.cgImage?.width == 1080)
            #expect(image?.cgImage?.height == 1920)
        }

        /// 카드 모서리 바깥이 비어 있어야 사용자 사진 위에 얹힌다.
        @Test func stickerCornerIsTransparent() throws {
            let image = try #require(WorkoutShareRenderer.stickerImage(model: threeRowModel,
                                                                      style: style))
            #expect(cornerAlpha(of: try #require(image.cgImage)) == 0)
        }

        /// 이미지를 1×1 컨텍스트에 원본 크기로 그리면 좌하단 모서리 픽셀 하나만 남는다.
        private func cornerAlpha(of image: CGImage) -> UInt8 {
            var pixel: [UInt8] = [0, 0, 0, 0]
            pixel.withUnsafeMutableBytes { buffer in
                let context = CGContext(data: buffer.baseAddress,
                                        width: 1,
                                        height: 1,
                                        bitsPerComponent: 8,
                                        bytesPerRow: 4,
                                        space: CGColorSpaceCreateDeviceRGB(),
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
                context?.draw(image, in: CGRect(x: 0,
                                                y: 0,
                                                width: image.width,
                                                height: image.height))
            }
            return pixel[3]
        }
    }
#endif
