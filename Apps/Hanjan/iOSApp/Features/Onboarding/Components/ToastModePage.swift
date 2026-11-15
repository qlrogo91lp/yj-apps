import SwiftUI

/// 온보딩 ③ 짠 모드. 기기와 무관한 카드 3컷: 점 1/3 `짠만` → 2/3 `짠만` → 3/3 `한 잔`.
struct ToastModePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 10) {
                Text("친구와 속도가 달라도\n괜찮아요")
                    .font(.system(size: 28, weight: .bold))
                Text("짠 모드를 켜면 짠할 때마다 한 번 눌러요.\n3번 중 1번이면 세 번째 짠에만 마셔요.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                ToastStepCard(filled: 1, total: 3)
                ToastStepCard(filled: 2, total: 3)
                ToastStepCard(filled: 3, total: 3)
            }
            Text("점이 다 차면 마실 차례입니다.")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(BrandColor.amber)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

/// 원형 점 + 그 차례의 버튼 모양. 그림이라 누를 수 없다.
private struct ToastStepCard: View {
    let filled: Int
    let total: Int

    private var isDrinkTurn: Bool {
        filled == total
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 5) {
                ForEach(1 ... total, id: \.self) { index in
                    Circle()
                        .fill(index <= filled ? BrandColor.amber : Color.clear)
                        .overlay(Circle().strokeBorder(BrandColor.amber, lineWidth: 1.5))
                        .frame(width: 10, height: 10)
                }
            }
            Text(isDrinkTurn ? "한 잔" : "짠만")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isDrinkTurn ? Color.black : BrandColor.amber)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isDrinkTurn ? BrandColor.amber : Color.clear, in: Capsule())
                .overlay(Capsule().strokeBorder(BrandColor.amber, lineWidth: isDrinkTurn ? 0 : 1))
            Text("\(filled)번째 짠")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(BrandColor.surface, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(filled)번째 짠, \(isDrinkTurn ? "한 잔 마실 차례" : "짠만")")
    }
}

#Preview {
    ToastModePage()
        .background(BrandColor.background)
        .preferredColorScheme(.dark)
}
