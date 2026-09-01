#if os(iOS)
    import SwiftUI
    import UIKit

    /// 강조색에서 스토리 배경 그라디언트의 두 색을 뽑는다.
    /// 딥링크로 넘기는 hex와 폴백 이미지에 그리는 배경이 같은 계산에서 나오게 하는 것이 목적이다.
    enum StoryGradient {
        /// 아래쪽 색은 각 RGB 채널에 이 비율을 곱한 값이다.
        static let darkenFactor: CGFloat = 0.6

        static func hexPair(from accent: Color) -> (top: String, bottom: String) {
            let (red, green, blue) = components(of: accent)
            return (hex(red, green, blue),
                    hex(red * darkenFactor, green * darkenFactor, blue * darkenFactor))
        }

        static func colors(from accent: Color) -> (top: Color, bottom: Color) {
            let (red, green, blue) = components(of: accent)
            return (accent,
                    Color(red: red * darkenFactor,
                          green: green * darkenFactor,
                          blue: blue * darkenFactor))
        }

        /// 알파는 무시하고 불투명으로 취급한다.
        private static func components(of color: Color) -> (CGFloat, CGFloat, CGFloat) {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return (red, green, blue)
        }

        private static func hex(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> String {
            String(format: "#%02X%02X%02X", channel(red), channel(green), channel(blue))
        }

        private static func channel(_ value: CGFloat) -> Int {
            Int((min(max(value, 0), 1) * 255).rounded())
        }
    }
#endif
