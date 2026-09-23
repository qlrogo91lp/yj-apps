import SwiftUI

/// 제품 스펙 7절의 다크 팔레트. RGB 채널은 8비트 HEX를 그대로 옮긴다.
enum HaruchiPalette {
    static let accent = rgb(0xFF, 0x95, 0x00)
    static let cardio = rgb(0x8C, 0xB4, 0xE8)
    static let hr = rgb(0xFF, 0x45, 0x3A)
    static let bg = rgb(0x1C, 0x1C, 0x18)
    static let surface = rgb(0x25, 0x25, 0x21)
    static let surface2 = rgb(0x2C, 0x2C, 0x27)
    static let surface3 = rgb(0x35, 0x35, 0x2E)
    static let line = rgb(0x33, 0x33, 0x2C)
    static let text = rgb(0xF2, 0xF0, 0xEA)
    static let dim = rgb(0x8E, 0x8C, 0x82)
    static let faint = rgb(0x5C, 0x5B, 0x53)
    static let cell = rgb(0x28, 0x28, 0x1F)

    /// 중간 3단계는 빈 칸과 브랜드색 사이를 RGB 기준 25%씩 보간한 불투명 색이다.
    static func grass(_ level: GrassLevel) -> Color {
        switch level {
        case .none: cell
        case .light: rgb(0x5E, 0x43, 0x17)
        case .medium: rgb(0x94, 0x5F, 0x10)
        case .heavy: rgb(0xC9, 0x7A, 0x08)
        case .peak: accent
        }
    }

    private static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
        Color(.sRGB, red: red / 255, green: green / 255, blue: blue / 255, opacity: 1)
    }
}
