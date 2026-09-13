#if os(iOS)
    import SwiftUI
    import UIKit
    import WorkoutCore

    /// 워크아웃 결과 카드를 이미지로 만들어 iOS 공유 시트로 넘기는 버튼.
    public struct WorkoutShareButton: View {
        private let result: WorkoutResult
        private let style: WorkoutShareStyle

        @State private var shared: SharedImage?

        public init(result: WorkoutResult, style: WorkoutShareStyle) {
            self.result = result
            self.style = style
        }

        public var body: some View {
            Button {
                share()
            } label: {
                Label(String(localized: "share_button", bundle: .module),
                      systemImage: "square.and.arrow.up")
            }
            .sheet(item: $shared) { ShareSheet(image: $0.image) }
        }

        @MainActor
        private func share() {
            let model = WorkoutShareCardModel(result: result)
            guard let image = WorkoutShareRenderer.image(model: model, style: style) else { return }
            shared = SharedImage(image: image)
        }
    }

    private struct SharedImage: Identifiable {
        let id = UUID()
        let image: UIImage
    }

    #Preview {
        WorkoutShareButton(
            result: WorkoutResult(durationSeconds: 2538,
                                  caloriesBurned: 312,
                                  averageHeartRate: 148),
            style: WorkoutShareStyle(accentColor: .green,
                                     logo: Image(systemName: "figure.tennis"))
        )
    }
#endif
