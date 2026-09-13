#if os(iOS)
    import SwiftUI
    import UIKit

    /// 강조색에서 공유 이미지 배경 그라디언트의 두 색을 뽑는다.
    enum StoryGradient {
        /// 아래쪽 색은 각 RGB 채널에 이 비율을 곱한 값이다.
        static let darkenFactor: CGFloat = 0.6

        static func colors(from accent: Color) -> (top: Color, bottom: Color) {
            let (red, green, blue) = components(of: accent)
            return (accent,
                    Color(red: red * darkenFactor,
                          green: green * darkenFactor,
                          blue: blue * darkenFactor))
        }

        /// 알파는 무시하고 불투명으로 취급한다.
        static func components(of color: Color) -> (CGFloat, CGFloat, CGFloat) {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return (red, green, blue)
        }
    }
#endif
