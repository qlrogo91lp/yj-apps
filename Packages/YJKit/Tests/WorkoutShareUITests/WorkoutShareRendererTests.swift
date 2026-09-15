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
            #expect(pixelAlpha(of: image, x: 0, y: 0) == 0)
        }

        /// 카드 한가운데는 불투명하다 — 투명하게 만들다 카드까지 비우지 않았는지.
        @Test func cardCenterIsOpaque() throws {
            let image = try #require(WorkoutShareRenderer.image(model: WorkoutShareCardModel(result: fullResult),
                                                                style: style)?.cgImage)
            #expect(pixelAlpha(of: image, x: image.width / 2, y: image.height / 2) == 255)
        }
    }
#endif
