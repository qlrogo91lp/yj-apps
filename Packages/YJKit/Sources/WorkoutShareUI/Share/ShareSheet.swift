#if os(iOS)
    import SwiftUI
    import UIKit

    /// UIActivityViewController를 SwiftUI에서 띄우기 위한 래퍼.
    /// 렌더가 탭 이후에 일어나므로 구성 시점에 아이템이 필요한 ShareLink를 쓸 수 없다.
    ///
    /// `UIImage` 가 아니라 PNG 파일을 넘긴다 — 이미지로 넘기면 받는 쪽이 JPEG 로 바꿔 모서리 투명이 사라진다.
    struct ShareSheet: UIViewControllerRepresentable {
        let fileURL: URL

        func makeUIViewController(context _: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        }

        func updateUIViewController(_: UIActivityViewController, context _: Context) {}
    }
#endif
