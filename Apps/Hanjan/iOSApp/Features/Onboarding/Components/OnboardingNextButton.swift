import SwiftUI

/// 온보딩 아래의 주 버튼(`다음` · `시작하기`). 시스템 강조 버튼에 앰버, 글자는 검정.
struct OnboardingNextButton: View {
    let title: String
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
    }
}

#Preview {
    OnboardingNextButton(title: "다음") {}
        .padding()
        .background(BrandColor.background)
        .preferredColorScheme(.dark)
}
