#if os(iOS)
    import SwiftUI
    import UIKit
    import WorkoutCore

    /// 워크아웃 결과를 인스타그램 스토리로 공유하는 버튼.
    /// 인스타그램이 있으면 스토리 편집기를 열고, 없으면 공유 시트로 폴백한다.
    public struct WorkoutShareButton: View {
        private let result: WorkoutResult
        private let style: WorkoutShareStyle
        private let instagramAppID: String

        @State private var fallback: FallbackImage?
        @State private var isPreparing = false

        public init(result: WorkoutResult, style: WorkoutShareStyle, instagramAppID: String) {
            self.result = result
            self.style = style
            self.instagramAppID = instagramAppID
        }

        public var body: some View {
            Button {
                share()
            } label: {
                Label(String(localized: "share_button", bundle: .module),
                      systemImage: "square.and.arrow.up")
            }
            .disabled(isPreparing)
            .sheet(item: $fallback) { ShareSheet(image: $0.image) }
        }

        @MainActor
        private func share() {
            isPreparing = true
            let model = WorkoutShareCardModel(result: result)

            guard InstagramStoryShare.isAvailable,
                  let sticker = WorkoutShareRenderer.stickerImage(model: model, style: style)?
                  .pngData()
            else {
                presentFallback(model: model)
                isPreparing = false
                return
            }

            let colors = StoryGradient.hexPair(from: style.accentColor)
            InstagramStoryShare.share(stickerPNG: sticker,
                                      topColor: colors.top,
                                      bottomColor: colors.bottom,
                                      appID: instagramAppID)
            { opened in
                isPreparing = false
                if !opened { presentFallback(model: model) }
            }
        }

        @MainActor
        private func presentFallback(model: WorkoutShareCardModel) {
            guard let image = WorkoutShareRenderer.standaloneImage(model: model, style: style)
            else { return }
            fallback = FallbackImage(image: image)
        }
    }

    private struct FallbackImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    #Preview {
        WorkoutShareButton(
            result: WorkoutResult(durationSeconds: 2538,
                                  caloriesBurned: 312,
                                  averageHeartRate: 148),
            style: WorkoutShareStyle(accentColor: .green,
                                     logo: Image(systemName: "figure.tennis")),
            instagramAppID: "1234567890"
        )
    }
#endif
