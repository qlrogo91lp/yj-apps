import SwiftUI

/// 첫 실행 온보딩 4장. 끝나면 `onFinish(한도)` — 한도 저장과 `hasOnboarded` 는 T9 가 잇는다.
struct OnboardingView: View {
    let onFinish: (_ limit: Double) -> Void

    @StateObject private var viewModel: OnboardingViewModel

    init(permissions: PermissionRequesting? = nil, onFinish: @escaping (_ limit: Double) -> Void) {
        self.onFinish = onFinish
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(permissions: permissions ?? SystemPermissionRequester()))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("건너뛰기") { viewModel.skip() }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .opacity(viewModel.canSkip ? 1 : 0)
                    .disabled(!viewModel.canSkip)
            }
            .padding(.horizontal, 20)
            .frame(height: 44)

            TabView(selection: $viewModel.page) {
                LimitStepPage(limit: viewModel.limit) { viewModel.setLimit($0) }
                    .tag(OnboardingViewModel.Page.limit)
                BothDevicesPage()
                    .tag(OnboardingViewModel.Page.bothDevices)
                ToastModePage()
                    .tag(OnboardingViewModel.Page.toastMode)
                PermissionPage(
                    notification: viewModel.notification,
                    location: viewModel.location,
                    onRequestNotification: { Task { await viewModel.requestNotifications() } },
                    onRequestLocation: { Task { await viewModel.requestLocation() } }
                )
                .tag(OnboardingViewModel.Page.permission)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .interactive))

            OnboardingNextButton(title: viewModel.primaryTitle) {
                if viewModel.isLastPage {
                    onFinish(viewModel.limit)
                } else {
                    withAnimation { viewModel.next() }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .background(BrandColor.background)
    }
}

#if DEBUG
    /// 프리뷰에서 시스템 권한 창을 띄우지 않는 대역.
    private final class PreviewPermissions: PermissionRequesting {
        func requestNotifications() async -> Bool {
            true
        }

        func requestLocation() async -> Bool {
            false
        }
    }

    #Preview {
        OnboardingView(permissions: PreviewPermissions()) { _ in }
            .preferredColorScheme(.dark)
    }
#endif
