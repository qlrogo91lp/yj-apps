#if os(iOS)
    import SwiftUI
    import Testing
    import WorkoutCore
    @testable import WorkoutShareUI

    @MainActor
    struct WorkoutShareRendererTests {
        private let style = WorkoutShareStyle(badgeColor: .green, logo: Image(systemName: "figure.tennis"))
        private let header = WorkoutShareHeader(title: "테니스",
                                                startedAt: Date(timeIntervalSince1970: 0),
                                                endedAt: Date(timeIntervalSince1970: 9351))

        private func image(heartRate: Double? = 136) -> UIImage? {
            WorkoutShareRenderer.image(
                model: WorkoutShareCardModel(
                    result: WorkoutResult(durationSeconds: 9351, caloriesBurned: 1343,
                                          averageHeartRate: heartRate, totalCaloriesBurned: 1584),
                    header: header
                ),
                style: style
            )
        }

        /// 이미지가 스토리 화면(1080×1920)이 아니라 카드 크기다 — 인스타가 배경으로 깔지 않고
        /// 사진 한 장으로 받게.
        @Test func imageIsCardSized() {
            #expect(image()?.cgImage?.width == Int(ShareCanvas.cardSize.width * ShareCanvas.scale))
            #expect(image()?.cgImage?.height == Int(ShareCanvas.cardSize.height * ShareCanvas.scale))
        }

        /// 심박이 없어도 칸을 빼지 않으므로 크기가 같다.
        @Test func missingHeartRateKeepsSameSize() {
            #expect(image(heartRate: nil)?.cgImage?.height == image()?.cgImage?.height)
        }

        /// 둥근 모서리 바깥은 투명이다. 불투명으로 구우면 모서리가 검게 찬다.
        @Test func cornerOutsideRoundingIsTransparent() throws {
            let cgImage = try #require(image()?.cgImage)
            #expect(pixelAlpha(of: cgImage, x: 0, y: 0) == 0)
        }

        /// 카드 한가운데는 불투명하다 — 투명하게 만들다 카드까지 비우지 않았는지.
        @Test func cardCenterIsOpaque() throws {
            let cgImage = try #require(image()?.cgImage)
            #expect(pixelAlpha(of: cgImage, x: cgImage.width / 2, y: cgImage.height / 2) == 255)
        }
    }
#endif
