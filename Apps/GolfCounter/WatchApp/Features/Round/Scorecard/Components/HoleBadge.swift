import SwiftUI

/// 스코어카드 셀의 홀 번호 원형 배지. 회색 원반은 `CircleIconButton`과 같은 톤이다 —
/// 다만 버튼이 아니라 표시 전용이라 별도 타입이다.
struct HoleBadge: View {
    let holeNumber: Int
    let sizing: ScorecardSizing

    var body: some View {
        Text("\(holeNumber)")
            .font(.system(size: sizing.badgeFont, weight: .medium, design: .rounded))
            .frame(width: sizing.badgeDiameter, height: sizing.badgeDiameter)
            .background(Color.gray.opacity(0.25), in: Circle())
    }
}

#Preview {
    HStack(spacing: 12) {
        HoleBadge(holeNumber: 1, sizing: .regular)
        HoleBadge(holeNumber: 18, sizing: .tight)
    }
}
