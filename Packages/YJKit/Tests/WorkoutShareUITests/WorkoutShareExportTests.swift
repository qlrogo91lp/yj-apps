#if os(iOS)
    import SwiftUI
    import Testing
    import UIKit
    import UniformTypeIdentifiers
    import WorkoutCore
    @testable import WorkoutShareUI

    @MainActor
    struct WorkoutShareExportTests {
        private func cardImage() throws -> UIImage {
            try #require(WorkoutShareRenderer.image(
                model: WorkoutShareCardModel(result: WorkoutResult(durationSeconds: 2538,
                                                                   caloriesBurned: 312,
                                                                   averageHeartRate: 148)),
                style: WorkoutShareStyle(accentColor: .green)
            ))
        }

        /// PNG 로 바꿔도 모서리 투명이 남는다. UIImage 를 그대로 넘기면 받는 쪽이 JPEG 로 바꿔 투명이 사라진다.
        @Test func pngDataKeepsTransparentCorner() throws {
            let image = try cardImage()
            let data = try #require(WorkoutShareExport.pngData(from: image))
            let decoded = try #require(UIImage(data: data)?.cgImage)
            #expect(pixelAlpha(of: decoded, x: 0, y: 0) == 0)
        }

        @Test func fileIsPNGOnDisk() throws {
            let image = try cardImage()
            let url = try #require(WorkoutShareExport.pngFile(from: image))
            #expect(url.pathExtension == "png")
            #expect(FileManager.default.fileExists(atPath: url.path))
        }

        /// 인스타 스토리에 길게 눌러 붙여넣으면 스티커가 된다 — PNG 타입으로 넣어야 투명이 남는다.
        @Test func copyPutsPNGOnPasteboard() throws {
            let pasteboard = try #require(UIPasteboard(name: UIPasteboard.Name("WorkoutShareExportTests"), create: true))
            defer { UIPasteboard.remove(withName: pasteboard.name) }
            let image = try cardImage()

            #expect(WorkoutShareExport.copySticker(image, to: pasteboard))

            let data = try #require(pasteboard.data(forPasteboardType: UTType.png.identifier))
            let decoded = try #require(UIImage(data: data)?.cgImage)
            #expect(pixelAlpha(of: decoded, x: 0, y: 0) == 0)
        }
    }
#endif
