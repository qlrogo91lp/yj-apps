import SwiftUI

/// 첫 실행(및 온보딩 버전이 오른 업데이트 직후)에 뜨는 4페이지.
///
/// 시트가 아니라 루트 교체로 띄운다 — 시트는 당겨서 닫히고 그러면 플래그가 안 남는다.
struct OnboardingView: View {
    let onFinished: () -> Void

    @State private var page = 0
    private let lastPage = 3

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
                    ) { CrownArrowsOverlay() }
                        .tag(0)

                    OnboardingScreenshotPage(
                        imageName: "OnboardingHealth",
                        title: String(localized: "onboarding_health_title"),
                        message: String(localized: "onboarding_health_body")
                    )
                    .tag(1)

                    OnboardingScreenshotPage(
                        imageName: "OnboardingShare",
                        title: String(localized: "onboarding_share_title"),
                        message: String(localized: "onboarding_share_body")
                    )
                    .tag(2)

                    OnboardingFeatureListPage(
                        title: String(localized: "onboarding_more_title"),
                        items: [
                            .init(
                                symbol: "applewatch.radiowaves.left.and.right",
                                title: String(localized: "onboarding_more_mirror_title"),
                                body: String(localized: "onboarding_more_mirror_body")
                            ),
                            .init(
                                symbol: "arrow.uturn.backward",
                                title: String(localized: "onboarding_more_undo_title"),
                                body: String(localized: "onboarding_more_undo_body")
                            ),
                            .init(
                                symbol: "lock.iphone",
                                title: String(localized: "onboarding_more_lock_title"),
                                body: String(localized: "onboarding_more_lock_body")
                            ),
                            .init(
                                symbol: "pause.circle",
                                title: String(localized: "onboarding_more_pause_title"),
                                body: String(localized: "onboarding_more_pause_body")
                            ),
                        ]
                    )
                    .tag(3)
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
