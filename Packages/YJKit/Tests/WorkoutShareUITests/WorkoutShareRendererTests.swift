#if os(iOS)
    import SwiftUI
    import Testing
    import WorkoutCore
    @testable import WorkoutShareUI

    @MainActor
    struct WorkoutShareRendererTests {
        private let style = WorkoutShareStyle(accentColor: .green)
        private let fullResult = WorkoutResult(durationSeconds: 2538,
                                               caloriesBurned: 312,
                                               averageHeartRate: 148)

        /// 이미지가 스토리 화면(1080×1920)이 아니라 카드 크기다 — 인스타가 화면 전체에 깔지 않고
        /// 사진 한 장으로 받아 옮기고 키울 수 있게.
        @Test func imageIsCardSized() {
            let model = WorkoutShareCardModel(result: fullResult)
            let card = ShareCanvas.cardSize(rowCount: model.rows.count, hasLogo: false)
            let image = WorkoutShareRenderer.image(model: model, style: style)
            #expect(image?.cgImage?.width == Int(card.width * ShareCanvas.scale))
            #expect(image?.cgImage?.height == Int(card.height * ShareCanvas.scale))
        }

        /// 행이 줄면 이미지도 그만큼 준다.
        @Test func fewerRowsShrinkImage() {
            let full = WorkoutShareRenderer.image(model: WorkoutShareCardModel(result: fullResult), style: style)
            let short = WorkoutShareRenderer.image(
                model: WorkoutShareCardModel(result: WorkoutResult(durationSeconds: 600,
                                                                   caloriesBurned: 0,
                                                                   averageHeartRate: nil)),
                style: style
            )
            let fullHeight = full?.cgImage?.height ?? 0
            let shortHeight = short?.cgImage?.height ?? 0
            #expect(shortHeight > 0)
            #expect(shortHeight < fullHeight)
        }

        /// 둥근 모서리 바깥은 투명이다. 불투명으로 구우면 모서리가 검게 찬다.
        @Test func cornerOutsideRoundingIsTransparent() throws {
            let image = try #require(WorkoutShareRenderer.image(model: WorkoutShareCardModel(result: fullResult),
                                                                style: style)?.cgImage)
            #expect(alpha(of: image, x: 0, y: 0) == 0)
        }

        /// 카드 한가운데는 불투명하다 — 투명하게 만들다 카드까지 비우지 않았는지.
        @Test func cardCenterIsOpaque() throws {
            let image = try #require(WorkoutShareRenderer.image(model: WorkoutShareCardModel(result: fullResult),
                                                                style: style)?.cgImage)
            #expect(alpha(of: image, x: image.width / 2, y: image.height / 2) == 255)
        }

        /// 픽셀 하나의 알파. 원본 포맷에 기대지 않도록 RGBA8 컨텍스트에 다시 그려서 읽는다.
        private func alpha(of image: CGImage, x: Int, y: Int) -> UInt8 {
            var pixel = [UInt8](repeating: 0, count: 4)
            pixel.withUnsafeMutableBytes { buffer in
                guard let context = CGContext(data: buffer.baseAddress,
                                              width: 1, height: 1,
                                              bitsPerComponent: 8, bytesPerRow: 4,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
                else { return }
                // CG 좌표는 아래가 원점 — 위에서 y 번째 픽셀이 (0,0) 에 오게 옮긴다.
                context.draw(image, in: CGRect(x: -x, y: y - image.height + 1,
                                               width: image.width, height: image.height))
            }
            return pixel[3]
        }
    }
#endif
