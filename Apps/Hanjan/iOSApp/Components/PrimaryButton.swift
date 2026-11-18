import SwiftUI

/// 주 버튼(`저장하기` 등). 시스템 강조 버튼에 앰버, 글자는 검정 — 앰버 위 흰 글자는 대비가 낮다.
struct PrimaryButton: View {
    let title: String
    var isEnabled = true
    var isDanger = false
    var isToast = false
    var height: CGFloat?
    let action: () -> Void

    var body: some View {
        Group {
            if let height {
                Button(action: action) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isToast ? BrandColor.amber : .black)
                        .frame(maxWidth: .infinity).frame(height: height)
                        .background(isToast ? BrandColor.amber.opacity(0.2) : (isDanger ? BrandColor.danger : BrandColor.amber), in: Capsule())
                }.buttonStyle(.plain)
            } else {
                Button(action: action) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(isDanger ? BrandColor.danger : BrandColor.amber)
            }
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

#Preview {
    VStack(spacing: 16) {
        PrimaryButton(title: "저장하기") {}
        PrimaryButton(title: "변경사항 저장", isEnabled: false) {}
    }
    .padding()
    .background(BrandColor.background)
    .preferredColorScheme(.dark)
}
