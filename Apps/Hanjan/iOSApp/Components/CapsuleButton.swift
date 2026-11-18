import SwiftUI

/// 보조 버튼. Ralli `UndoButton` 과 같은 얇은 캡슐.
/// `.neutral` 은 흰색 10% 채움 + 20% 테두리, `.danger`(삭제)는 채움 없이 빨강 테두리 + 글자.
struct CapsuleButton: View {
    enum Style { case neutral, danger }

    let title: String
    var style: Style = .neutral
    var isEnabled = true
    var height: CGFloat?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(style == .danger ? BrandColor.danger : .white.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .padding(.vertical, height == nil ? 12 : 0)
                .background(style == .neutral ? .white.opacity(0.1) : Color.clear, in: Capsule())
                .overlay(Capsule().strokeBorder(
                    style == .danger ? BrandColor.danger : .white.opacity(0.2),
                    lineWidth: 1
                ))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

#Preview {
    VStack(spacing: 16) {
        CapsuleButton(title: "나중에 하기") {}
        CapsuleButton(title: "기록 삭제", style: .danger) {}
    }
    .padding()
    .background(BrandColor.background)
    .preferredColorScheme(.dark)
}
