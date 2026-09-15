#if os(iOS)
    import SwiftUI
    import Testing
    @testable import WorkoutShareUI

    struct BadgeForegroundTests {
        /// Ralli 라임 — 밝은 원에는 검은 로고.
        @Test func lightBadgeGetsBlackLogo() {
            let color = BadgeForeground.logoColor(badge: Color(red: 0.6784, green: 1.0, blue: 0.2549), explicit: nil)
            expectComponents(of: color, equal: (0, 0, 0))
        }

        /// 하루치 주황 — 흰색보다 검정이 대비가 높다.
        @Test func orangeBadgeGetsBlackLogo() {
            let color = BadgeForeground.logoColor(badge: Color(red: 1.0, green: 0.58, blue: 0.0), explicit: nil)
            expectComponents(of: color, equal: (0, 0, 0))
        }

        /// 골프 짙은 초록 — 어두운 원에는 흰 로고.
        @Test func darkBadgeGetsWhiteLogo() {
            let color = BadgeForeground.logoColor(badge: Color(red: 0, green: 0.3216, blue: 0.0392), explicit: nil)
            expectComponents(of: color, equal: (1, 1, 1))
        }

        /// 앱이 색을 정했으면 그대로 쓴다 — 골프는 초록 위에 크림색을 쓴다.
        @Test func explicitLogoColorWins() {
            let cream = Color(red: 0.9686, green: 0.9529, blue: 0.9059)
            let color = BadgeForeground.logoColor(badge: Color(red: 0, green: 0.3216, blue: 0.0392), explicit: cream)
            expectComponents(of: color, equal: (0.9686, 0.9529, 0.9059))
        }

        private func expectComponents(of color: Color,
                                      equal expected: (CGFloat, CGFloat, CGFloat),
                                      sourceLocation: SourceLocation = #_sourceLocation)
        {
            let (red, green, blue) = BadgeForeground.components(of: color)
            for (actual, want) in [(red, expected.0), (green, expected.1), (blue, expected.2)] {
                #expect(abs(actual - want) < 0.001, sourceLocation: sourceLocation)
            }
        }
    }
#endif
