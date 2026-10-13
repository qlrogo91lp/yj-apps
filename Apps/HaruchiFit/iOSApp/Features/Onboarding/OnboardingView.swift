import SwiftUI

/// 첫 실행(및 온보딩 버전이 오른 업데이트 직후)에 탭 화면 대신 뜨는 3장.
///
/// 시트가 아니라 루트 교체로 띄운다 — 시트는 당겨서 닫히고 그러면 본 버전이 안 남는다.
/// 건너뛰기는 없다. 마지막 장의 `계속` 이 끝나는 유일한 길이고, 그 뒤에 건강 권한 시트가 뜬다.
struct OnboardingView: View {
    let onFinished: () -> Void

    @State private var page = 0
    private let lastPage = 2

    var body: some View {
        ZStack {
            HaruchiPalette.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    OnboardingPage(title: "onboarding_concept_title", message: "onboarding_concept_body") {
                        OnboardingGrassPicture()
                    }
                    .tag(0)

                    OnboardingPage(title: "onboarding_watch_title",
                                   message: "onboarding_watch_body",
                                   note: "onboarding_watch_note")
                    {
                        OnboardingWatchPicture()
                    }
                    .tag(1)

                    OnboardingPage(title: "onboarding_health_title", message: "onboarding_health_body") {
                        OnboardingHealthPicture()
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
                    Text(page < lastPage ? "btn_next" : "btn_continue")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(HaruchiPalette.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
    }
}

#Preview {
    OnboardingView(onFinished: {})
        .preferredColorScheme(.dark)
}
