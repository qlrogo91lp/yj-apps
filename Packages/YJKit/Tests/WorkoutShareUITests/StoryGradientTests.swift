#if os(iOS)
    import SwiftUI
    import Testing
    @testable import WorkoutShareUI

    struct StoryGradientTests {
        @Test func topKeepsAccentAndBottomIsDarkened() {
            let pair = StoryGradient.colors(from: Color(red: 1, green: 0, blue: 0))
            expectComponents(of: pair.top, equal: (1, 0, 0))
            expectComponents(of: pair.bottom, equal: (0.6, 0, 0))
        }

        @Test func whiteDarkensToMidGray() {
            let pair = StoryGradient.colors(from: .white)
            expectComponents(of: pair.top, equal: (1, 1, 1))
            expectComponents(of: pair.bottom, equal: (0.6, 0.6, 0.6))
        }

        @Test func blackStaysBlackInBothStops() {
            let pair = StoryGradient.colors(from: .black)
            expectComponents(of: pair.top, equal: (0, 0, 0))
            expectComponents(of: pair.bottom, equal: (0, 0, 0))
        }

        private func expectComponents(of color: Color,
                                      equal expected: (CGFloat, CGFloat, CGFloat),
                                      sourceLocation: SourceLocation = #_sourceLocation)
        {
            let (red, green, blue) = StoryGradient.components(of: color)
            for (actual, want) in [(red, expected.0), (green, expected.1), (blue, expected.2)] {
                #expect(abs(actual - want) < 0.001, sourceLocation: sourceLocation)
            }
        }
    }
#endif
