import SwiftUI

/// 오버파 세 상태(언더파·이븐·오버파)를 색으로 구분한다 (spec §2).
/// 구체 색값은 디자인 확정 시 이 한 곳만 고치면 된다.
enum ScorePalette {
    static func color(for relativeToPar: Int) -> Color {
        if relativeToPar < 0 {
            return .blue
        }
        if relativeToPar == 0 {
            return .green
        }
        return .orange
    }
}
