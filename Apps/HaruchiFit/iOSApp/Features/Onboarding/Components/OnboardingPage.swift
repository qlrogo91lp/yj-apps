import SwiftUI

/// 온보딩 한 장의 공통 배치 — 그림 자리 + 제목 + 본문 + (선택) 작은 글씨.
///
/// 그림은 4:5 로 고정하고 글 영역 높이도 고정한다. 장마다 글 길이가 달라도 그림 위치가 흔들리지 않는다.
struct OnboardingPage<Picture: View>: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var note: LocalizedStringKey?
    @ViewBuilder let picture: () -> Picture

    private let pictureRatio: CGFloat = 0.8
    private let textHeight: CGFloat = 190
    private let sidePadding: CGFloat = 32
    private let gap: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            // `TabView` 는 폭을 무한으로 제안한다 — 폭과 높이를 둘 다 재서 작은 쪽으로 잡는다.
            let availableWidth = geo.size.width - sidePadding * 2
            let availableHeight = geo.size.height - textHeight - gap
            let width = max(0, min(availableWidth, availableHeight * pictureRatio))

            VStack(spacing: gap) {
                picture()
                    .frame(width: width, height: width / pictureRatio)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(spacing: 12) {
                    Text(title)
                        .font(.title2.bold())
                        .foregroundStyle(HaruchiPalette.text)
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(HaruchiPalette.dim)
                        .multilineTextAlignment(.center)
                    if let note {
                        Text(note)
                            .font(.footnote)
                            .foregroundStyle(HaruchiPalette.faint)
                            .multilineTextAlignment(.center)
                    }
                }
                .minimumScaleFactor(0.85)
                .frame(height: textHeight, alignment: .top)
                .padding(.horizontal, sidePadding)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}
