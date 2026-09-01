#if os(iOS)
    import Foundation

    /// 인스타그램 스토리 딥링크에 넘길 URL과 페이스트보드 아이템을 만든다. 부수효과가 없어 그대로 검증할 수 있다.
    enum InstagramStoryLink {
        static let scheme = "instagram-stories"
        static let stickerImageKey = "com.instagram.sharedSticker.stickerImage"
        static let backgroundTopColorKey = "com.instagram.sharedSticker.backgroundTopColor"
        static let backgroundBottomColorKey = "com.instagram.sharedSticker.backgroundBottomColor"

        /// 스킴 등록 여부를 `canOpenURL`로 물을 때 쓴다. appID가 필요 없다.
        static var probeURL: URL? { URL(string: "\(scheme)://share") }

        static func storyURL(appID: String) -> URL? {
            let trimmed = appID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            var components = URLComponents()
            components.scheme = scheme
            components.host = "share"
            components.queryItems = [URLQueryItem(name: "source_application", value: trimmed)]
            return components.url
        }

        static func pasteboardItems(stickerPNG: Data,
                                    topColor: String,
                                    bottomColor: String) -> [[String: Any]]
        {
            [[
                stickerImageKey: stickerPNG,
                backgroundTopColorKey: topColor,
                backgroundBottomColorKey: bottomColor,
            ]]
        }
    }
#endif
