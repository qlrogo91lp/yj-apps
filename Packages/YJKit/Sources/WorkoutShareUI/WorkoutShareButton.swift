#if os(iOS)
    import SwiftUI
    import UIKit
    import WorkoutCore

    /// 워크아웃 결과 카드를 내보내는 버튼. 누르면 메뉴가 뜬다 — 공유 시트, 또는 스티커로 복사.
    ///
    /// 공유 시트로 넘긴 사진에는 인스타가 배경을 붙인다. 배경 없는 스티커는 클립보드에 넣고
    /// 스토리에서 붙여넣는 경로로만 된다 (딥링크는 Meta App ID 가 필요해 걷어냈다).
    public struct WorkoutShareButton: View {
        private let result: WorkoutResult
        private let header: WorkoutShareHeader
        private let style: WorkoutShareStyle

        @State private var shared: SharedFile?
        @State private var showCopied = false

        public init(result: WorkoutResult, header: WorkoutShareHeader, style: WorkoutShareStyle) {
            self.result = result
            self.header = header
            self.style = style
        }

        public var body: some View {
            Menu {
                Button {
                    share()
                } label: {
                    Label(String(localized: "share_menu_share", bundle: .module),
                          systemImage: "square.and.arrow.up")
                }
                Button {
                    copySticker()
                } label: {
                    Label(String(localized: "share_menu_copy_sticker", bundle: .module),
                          systemImage: "doc.on.doc")
                }
            } label: {
                Label(String(localized: "share_button", bundle: .module),
                      systemImage: "square.and.arrow.up")
            }
            .sheet(item: $shared) { ShareSheet(fileURL: $0.url) }
            .alert(String(localized: "share_copied_title", bundle: .module), isPresented: $showCopied) {
                Button(String(localized: "share_copied_ok", bundle: .module)) {}
            } message: {
                Text(String(localized: "share_copied_message", bundle: .module))
            }
        }

        @MainActor
        private func renderCard() -> UIImage? {
            WorkoutShareRenderer.image(model: WorkoutShareCardModel(result: result, header: header), style: style)
        }

        @MainActor
        private func share() {
            guard let image = renderCard(), let url = WorkoutShareExport.pngFile(from: image) else { return }
            shared = SharedFile(url: url)
        }

        @MainActor
        private func copySticker() {
            guard let image = renderCard(), WorkoutShareExport.copySticker(image) else { return }
            showCopied = true
        }
    }

    private struct SharedFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    #Preview {
        WorkoutShareButton(
            result: WorkoutResult(durationSeconds: 9351, caloriesBurned: 1343,
                                  averageHeartRate: 136, totalCaloriesBurned: 1584),
            header: WorkoutShareHeader(title: "테니스", startedAt: Date().addingTimeInterval(-9351), endedAt: Date()),
            style: WorkoutShareStyle(badgeColor: .green, logo: Image(systemName: "tennisball"))
        )
    }
#endif
