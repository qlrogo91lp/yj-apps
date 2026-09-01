#if os(iOS)
    import SwiftUI
    import UIKit

    /// UIActivityViewController를 SwiftUI에서 띄우기 위한 래퍼.
    /// 렌더가 탭 이후에 일어나므로 구성 시점에 아이템이 필요한 ShareLink를 쓸 수 없다.
    struct ShareSheet: UIViewControllerRepresentable {
        let image: UIImage

        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: [image], applicationActivities: nil)
        }

        func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
    }
#endif
