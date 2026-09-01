#if os(iOS)
    import SwiftUI
    import Testing
    @testable import WorkoutShareUI

    struct StoryGradientTests {
        @Test func topKeepsAccentAndBottomIsDarkened() {
            let pair = StoryGradient.hexPair(from: Color(red: 1, green: 0, blue: 0))
            #expect(pair.top == "#FF0000")
            #expect(pair.bottom == "#990000")
        }

        @Test func whiteDarkensToMidGray() {
            let pair = StoryGradient.hexPair(from: .white)
            #expect(pair.top == "#FFFFFF")
            #expect(pair.bottom == "#999999")
        }

        @Test func blackStaysBlackInBothStops() {
            let pair = StoryGradient.hexPair(from: .black)
            #expect(pair.top == "#000000")
            #expect(pair.bottom == "#000000")
        }

        @Test func hexIsHashPlusSixUppercaseDigits() {
            let pair = StoryGradient.hexPair(from: Color(red: 0.2, green: 0.4, blue: 0.6))
            for value in [pair.top, pair.bottom] {
                #expect(value.count == 7)
                #expect(value.hasPrefix("#"))
                #expect(value.dropFirst().allSatisfy { $0.isHexDigit && !$0.isLowercase })
            }
        }

        /// 두 진입점이 어긋나면 딥링크 배경색과 폴백 이미지 배경색이 갈린다.
        @Test func colorsAgreeWithHexPair() {
            let accent = Color(red: 0.2, green: 0.4, blue: 0.6)
            let expected = StoryGradient.hexPair(from: accent)
            let derived = StoryGradient.colors(from: accent)
            #expect(StoryGradient.hexPair(from: derived.top).top == expected.top)
            #expect(StoryGradient.hexPair(from: derived.bottom).top == expected.bottom)
        }
    }
#endif
