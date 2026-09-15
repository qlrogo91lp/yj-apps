#if os(iOS)
    import SwiftUI
    import UIKit

    /// 머리줄 원형 로고 안의 로고 색을 정한다.
    enum BadgeForeground {
        /// 앱이 색을 넘겼으면 그대로, 아니면 원 배경과 대비가 더 큰 쪽(검정/흰색)을 고른다.
        /// 라임·주황 같은 밝은 원은 검정, 짙은 초록 같은 어두운 원은 흰색이 된다.
        static func logoColor(badge: Color, explicit: Color?) -> Color {
            if let explicit { return explicit }
            let luminance = relativeLuminance(of: badge)
            let againstBlack = (luminance + 0.05) / 0.05
            let againstWhite = 1.05 / (luminance + 0.05)
            return againstBlack >= againstWhite ? .black : .white
        }

        /// WCAG 상대 휘도.
        static func relativeLuminance(of color: Color) -> CGFloat {
            let (red, green, blue) = components(of: color)
            func linear(_ channel: CGFloat) -> CGFloat {
                channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
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
