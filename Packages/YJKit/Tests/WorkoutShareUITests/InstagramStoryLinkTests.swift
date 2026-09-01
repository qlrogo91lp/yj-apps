#if os(iOS)
    import Foundation
    import Testing
    @testable import WorkoutShareUI

    struct InstagramStoryLinkTests {
        @Test func storyURLCarriesAppIDAsSourceApplication() {
            #expect(InstagramStoryLink.storyURL(appID: "1234567890")?.absoluteString
                == "instagram-stories://share?source_application=1234567890")
        }

        /// 앱이 App ID를 안 넣은 실수가 조용히 통과하지 않도록 한다.
        @Test func storyURLIsNilWhenAppIDIsBlank() {
            #expect(InstagramStoryLink.storyURL(appID: "") == nil)
            #expect(InstagramStoryLink.storyURL(appID: "   ") == nil)
        }

        @Test func probeURLNeedsNoAppID() {
            #expect(InstagramStoryLink.probeURL?.absoluteString == "instagram-stories://share")
        }

        @Test func pasteboardItemsHoldExactlyThreeKeysInOneItem() {
            let items = InstagramStoryLink.pasteboardItems(stickerPNG: Data([0x01]),
                                                          topColor: "#FF0000",
                                                          bottomColor: "#990000")
            #expect(items.count == 1)
            #expect(Set(items[0].keys) == [
                "com.instagram.sharedSticker.stickerImage",
                "com.instagram.sharedSticker.backgroundTopColor",
                "com.instagram.sharedSticker.backgroundBottomColor",
            ])
        }

        @Test func pasteboardItemsPassValuesThrough() {
            let png = Data([0xDE, 0xAD, 0xBE, 0xEF])
            let items = InstagramStoryLink.pasteboardItems(stickerPNG: png,
                                                          topColor: "#112233",
                                                          bottomColor: "#0A141F")
            #expect(items[0][InstagramStoryLink.stickerImageKey] as? Data == png)
            #expect(items[0][InstagramStoryLink.backgroundTopColorKey] as? String == "#112233")
            #expect(items[0][InstagramStoryLink.backgroundBottomColorKey] as? String == "#0A141F")
        }
    }
#endif
