import SwiftUI

/// 스크린샷 한 장 + 제목 + 본문. 이미지 위에 얹을 게 있으면 `overlay` 로 넘긴다 (크라운 화살표).
///
/// 본문 파라미터를 `body` 로 두면 `View.body` 와 이름이 겹쳐 컴파일이 안 된다.
struct OnboardingScreenshotPage<Overlay: View>: View {
    let imageName: String
    let title: String
    let message: String
    @ViewBuilder let overlay: () -> Overlay

    init(
        imageName: String,
        title: String,
        message: String,
        @ViewBuilder overlay: @escaping () -> Overlay = { EmptyView() }
    ) {
        self.imageName = imageName
        self.title = title
        self.message = message
        self.overlay = overlay
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay { overlay() }
                .frame(maxHeight: 420)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OnboardingScreenshotPage(
            imageName: "OnboardingHealth",
            title: "건강 앱에 기록됩니다",
            message: "경기마다 테니스 워크아웃으로 저장됩니다."
        )
    }
}
