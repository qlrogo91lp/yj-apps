import SwiftUI

/// 스크린샷 한 장(또는 반복 영상) + 제목 + 본문. 이미지 위에 얹을 게 있으면 `overlay` 로 넘긴다 (크라운 화살표).
///
/// `videoName` 을 주면 번들의 `<이름>-<ko|en>.mp4`, 없으면 언어 공통 `<이름>.mp4` 를 소리 없이 반복 재생한다. 영상이 없거나
/// 시스템의 "동작 줄이기" 가 켜져 있으면 `imageName` 의 정지 이미지를 보여 준다.
///
/// 본문 파라미터를 `body` 로 두면 `View.body` 와 이름이 겹쳐 컴파일이 안 된다.
struct OnboardingScreenshotPage<Overlay: View>: View {
    let imageName: String
    let videoName: String?
    /// 이 페이지가 지금 화면에 보이는지. 영상은 보일 때만 재생한다.
    let isActive: Bool
    let title: String
    let message: String
    @ViewBuilder let overlay: () -> Overlay

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        imageName: String,
        videoName: String? = nil,
        isActive: Bool = true,
        title: String,
        message: String,
        @ViewBuilder overlay: @escaping () -> Overlay = { EmptyView() }
    ) {
        self.imageName = imageName
        self.videoName = videoName
        self.isActive = isActive
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
                media
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

private extension OnboardingScreenshotPage {
    @ViewBuilder
    var media: some View {
        if let videoURL, !reduceMotion {
            LoopingVideo(url: videoURL, isPlaying: isActive)
        } else {
            Image(imageName)
                .resizable()
                .scaledToFit()
        }
    }

    /// 앱 언어에 맞는 영상. 번들에서 고른 언어(`preferredLocalizations`)가 한국어면 ko, 아니면 en —
    /// 이미지 에셋의 로케일 선택과 같은 기준이다.
    var videoURL: URL? {
        guard let videoName else { return nil }
        let language = Bundle.main.preferredLocalizations.first == "ko" ? "ko" : "en"
        return Bundle.main.url(forResource: "\(videoName)-\(language)", withExtension: "mp4")
            ?? Bundle.main.url(forResource: videoName, withExtension: "mp4")
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        OnboardingScreenshotPage(
            imageName: "OnboardingHealth",
            title: "건강 앱에 기록돼요",
            message: "라운드마다 골프 운동으로 저장돼요."
        )
    }
}
