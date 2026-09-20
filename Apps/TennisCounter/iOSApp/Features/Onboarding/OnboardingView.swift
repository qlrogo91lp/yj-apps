import SwiftUI

/// 첫 실행(및 온보딩 버전이 오른 업데이트 직후)에 뜨는 5페이지.
///
/// 1~3 이 워치 사용법, 4~5 가 그 결과물이다. 시트가 아니라 루트 교체로 띄운다 —
/// 시트는 당겨서 닫히고 그러면 플래그가 안 남는다.
struct OnboardingView: View {
    let onFinished: () -> Void

    @State private var page = 0
    private let lastPage = 4

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
                        imageName: "OnboardingCrown",
                        title: String(localized: "onboarding_crown_title"),
                        message: String(localized: "onboarding_crown_body")
                    )
                    .tag(0)

                    OnboardingScreenshotPage(
                        imageName: "OnboardingSwipe",
                        title: String(localized: "onboarding_swipe_title"),
                        message: String(localized: "onboarding_swipe_body")
                    )
                    .tag(1)

                    OnboardingScreenshotPage(
                        imageName: "OnboardingComplication",
                        title: String(localized: "onboarding_complication_title"),
                        message: String(localized: "onboarding_complication_body")
                    )
                    .tag(2)

                    OnboardingScreenshotPage(
                        imageName: "OnboardingHealth",
                        title: String(localized: "onboarding_health_title"),
                        message: String(localized: "onboarding_health_body")
                    )
                    .tag(3)

                    OnboardingScreenshotPage(
                        imageName: "OnboardingShare",
                        title: String(localized: "onboarding_share_title"),
                        message: String(localized: "onboarding_share_body")
                    )
                    .tag(4)
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
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.brand, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
    }
}

#Preview {
    OnboardingView(onFinished: {})
}
