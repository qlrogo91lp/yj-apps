import SwiftUI

extension Color {
    /// 앱 아이콘 그라디언트 기준색 (GolfCounter.icon의 automatic-gradient 값, #00520A)
    /// 위젯 타깃은 소스를 공유하지 않으므로 ComplicationApp/BrandColor.swift에 같은 값이 따로 있다.
    static let brand = Color(red: 0, green: 0.3216, blue: 0.0392)
    /// brand 배경 위에 얹는 전경색 — 아이콘 SVG의 채움색(#F7F3E7)과 맞춘다.
    static let brandForeground = Color(red: 0.9686, green: 0.9529, blue: 0.9059)
}
