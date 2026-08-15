import SwiftUI

/// 회색 원반 위 아이콘 하나 — 취소·이전/다음 홀이 공유하는 원형 버튼이다 (spec §5).
///
/// Par 버튼과 같은 시각 계열(회색 배경 원)로 맞춰, 화면의 보조 조작이
/// 전부 한 가족으로 읽히게 한다. 링과 모드 알약만 색을 가진다.
struct CircleIconButton: View {
    let systemName: String
    let size: CGFloat
    /// 시각 크기 밖으로 균일하게 넓히는 탭 영역. `.contentShape`만 키우므로 레이아웃에
    /// 보고되는 크기는 그대로다 — 이웃에게 자리를 뺏지 않는다.
    ///
    /// 그래도 **양옆에 조작 가능한 뷰가 붙어 있으면 쓰지 말 것** — 겹치는 자리에서
    /// 어느 쪽이 탭을 가져갈지 SwiftUI가 보장해주지 않는다. 화살표처럼 한쪽이 링(가장
    /// 자주 쓰는 탭 타깃)인 경우는 호출부에서 세로 방향으로만 `.frame`을 키우는
    /// 별도 방식을 쓴다 — `CountingView.ringArea` 참조.
    var hitInset: CGFloat = 0
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
        .contentShape(Circle().inset(by: -hitInset))
    }
}

#Preview {
    HStack {
        CircleIconButton(systemName: "chevron.left", size: 30) {}
        CircleIconButton(systemName: "arrow.uturn.backward", size: 30) {}
        CircleIconButton(systemName: "chevron.right", size: 30) {}
    }
}
