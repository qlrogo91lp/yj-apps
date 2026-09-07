import SwiftUI

extension Color {
    /// #FF9500 — 하루치 핏 브랜드 오렌지.
    ///
    /// **타깃마다 따로 둔다** — 골프·테니스도 `iOSApp/`·`ComplicationApp/` 에 같은 값을
    /// 복제해 갖는다. 색 토큰은 작고 플랫폼별로 갈릴 수 있어 공유 비용이 더 크다.
    static let brandOrange = Color(red: 1.0, green: 0.58, blue: 0.0)
}
