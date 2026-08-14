import SwiftUI

/// 회색 원반 위 아이콘 하나 — 취소·이전/다음 홀이 공유하는 원형 버튼이다 (spec §5).
///
/// Par 버튼과 같은 시각 계열(회색 배경 원)로 맞춰, 화면의 보조 조작이
/// 전부 한 가족으로 읽히게 한다. 링과 모드 알약만 색을 가진다.
struct CircleIconButton: View {
    let systemName: String
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: size, height: size)
                .background(Color.gray.opacity(0.25), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack {
        CircleIconButton(systemName: "chevron.left", size: 30) {}
        CircleIconButton(systemName: "arrow.uturn.backward", size: 30) {}
        CircleIconButton(systemName: "chevron.right", size: 30) {}
    }
}
