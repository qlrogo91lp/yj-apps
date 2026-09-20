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

    /// 그림 자리의 가로세로비. 5장을 이 비율로 내보내면 박스를 꽉 채운다.
    private let imageRatio: CGFloat = 0.8
    /// 본문 영역 높이. 본문이 2~3줄로 페이지마다 달라, 고정하지 않으면 그림 자리가 페이지마다 달라진다.
    private let textHeight: CGFloat = 112
    private let sidePadding: CGFloat = 32
    private let gap: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            // `TabView` 는 폭을 무한으로 제안한다. `aspectRatio` 에만 맡기면 높이만 보고 폭을 정해
            // 화면을 넘으므로, 폭과 높이를 둘 다 재서 작은 쪽으로 잡는다.
            let availableWidth = geo.size.width - sidePadding * 2
            let availableHeight = geo.size.height - textHeight - gap
            let width = max(0, min(availableWidth, availableHeight * imageRatio))

            VStack(spacing: gap) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width, height: width / imageRatio)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay { overlay() }

                VStack(spacing: 12) {
                    Text(title)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                .frame(height: textHeight, alignment: .top)
                .padding(.horizontal, sidePadding)
            }
            .frame(width: geo.size.width, height: geo.size.height)
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
