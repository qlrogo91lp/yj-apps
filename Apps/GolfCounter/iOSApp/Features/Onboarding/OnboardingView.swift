import SwiftUI

/// 첫 실행(및 온보딩 버전이 오른 업데이트 직후)에 뜨는 3페이지.
///
/// 1~2 가 워치 사용법, 3 이 빠른 진입이다. 시트가 아니라 루트 교체로 띄운다 —
/// 시트는 당겨서 닫히고 그러면 플래그가 안 남는다.
struct OnboardingView: View {
    let onFinished: () -> Void

    @State private var page = 0
    private let lastPage = 2

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    if page < lastPage {
                        Button(String(localized: "onboarding_skip"), action: onFinished)
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                }
                .frame(height: 44)

                TabView(selection: $page) {
                    OnboardingScreenshotPage(
                        imageName: "OnboardingMode",
                        videoName: "onboarding-mode",
                        isActive: page == 0,
                        title: String(localized: "onboarding_mode_title"),
                        message: String(localized: "onboarding_mode_body")
                    )
                    .tag(0)

                    OnboardingScreenshotPage(
                        imageName: "OnboardingCrown",
                        videoName: "onboarding-crown",
                        isActive: page == 1,
                        title: String(localized: "onboarding_crown_title"),
                        message: String(localized: "onboarding_crown_body")
                    )
                    .tag(1)

                    OnboardingScreenshotPage(
                        imageName: "OnboardingComplication",
                        title: String(localized: "onboarding_complication_title"),
                        message: String(localized: "onboarding_complication_body")
                    ) {
                        OnboardingComplicationRing()
                    }
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Button {
                    if page < lastPage {
                        withAnimation { page += 1 }
                    } else {
                        onFinished()
                    }
                } label: {
                    Text(page < lastPage
                        ? String(localized: "onboarding_next")
                        : String(localized: "onboarding_start"))
                        .font(.headline)
                        .foregroundStyle(Color.brandForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.brand, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    OnboardingView(onFinished: {})
}
