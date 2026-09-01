#if os(iOS)
    import Foundation
    import UIKit

    /// 페이스트보드에 스티커를 올리고 인스타그램 스토리 편집기를 연다.
    @MainActor
    enum InstagramStoryShare {
        /// 페이스트보드에 남겨두는 시간. Meta 권장값이다.
        private static let pasteboardLifetime: TimeInterval = 300

        /// 스킴이 등록되어 있고 인스타그램이 설치되어 있는가.
        /// 앱 Info.plist에 LSApplicationQueriesSchemes가 없으면 항상 false다 —
        /// 설정 누락과 미설치가 같은 경로(공유 시트 폴백)를 타는 것은 의도된 동작이다.
        static var isAvailable: Bool {
            guard let url = InstagramStoryLink.probeURL else { return false }
            return UIApplication.shared.canOpenURL(url)
        }

        /// 스토리 편집기를 열었으면 true. false면 호출자가 공유 시트로 폴백한다.
        static func share(stickerPNG: Data,
                          topColor: String,
                          bottomColor: String,
                          appID: String,
                          completion: @escaping (Bool) -> Void)
        {
            guard isAvailable, let url = InstagramStoryLink.storyURL(appID: appID) else {
                completion(false)
                return
            }
            UIPasteboard.general.setItems(
                InstagramStoryLink.pasteboardItems(stickerPNG: stickerPNG,
                                                  topColor: topColor,
                                                  bottomColor: bottomColor),
                options: [.expirationDate: Date().addingTimeInterval(pasteboardLifetime)]
            )
            UIApplication.shared.open(url, options: [:], completionHandler: completion)
        }
    }
#endif
