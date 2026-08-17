import SwiftUI

/// 홀 수 선택 행 — 라벨 + 값 버튼 (spec §3.4).
///
/// tennis_counter `ModeView`의 게임 수(4→5→6) 컨트롤과 같은 모양이다. 홀 수는 불리언이
/// 아니라 값이라 스위치보다 성격이 맞고, 9와 18 중 무엇인지가 숫자로 항상 보인다.
struct HoleCountSelector: View {
    let holeCount: Int
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Text(String(localized: "home_hole_count"))
                .font(.system(size: 14))
            Spacer()
            Button(action: onToggle) {
                Text("\(holeCount)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 32)
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    HoleCountSelector(holeCount: 18, onToggle: {})
}
