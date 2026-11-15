import SwiftUI

/// 주 버튼(`저장하기` 등). 시스템 강조 버튼에 앰버, 글자는 검정 — 앰버 위 흰 글자는 대비가 낮다.
struct RecordPrimaryButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(BrandColor.amber)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }
}

#Preview {
    VStack(spacing: 16) {
        RecordPrimaryButton(title: "저장하기") {}
        RecordPrimaryButton(title: "변경사항 저장", isEnabled: false) {}
    }
    .padding()
    .background(BrandColor.background)
    .preferredColorScheme(.dark)
}
