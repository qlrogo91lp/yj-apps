@testable import Hanjan
import Testing

/// 온보딩 ViewModel 테스트. 대상 폴더(`iOSApp/Features/Onboarding/`)를 따르면 `iosTests/Onboarding/` 자리지만
/// 플랜의 T5 소유 폴더가 `iosTests/Settings/` 뿐이라 여기에 둔다.
@MainActor
struct OnboardingViewModelTests {
    @MainActor
    final class FakePermissions: PermissionRequesting {
        var notificationAnswer = true
        var locationAnswer = false
        private(set) var notificationCalls = 0
        private(set) var locationCalls = 0

        func requestNotifications() async -> Bool {
            notificationCalls += 1
            return notificationAnswer
        }

        func requestLocation() async -> Bool {
            locationCalls += 1
            return locationAnswer
        }
    }

    @Test func startsOnLimitPageWithDefault8() {
        let viewModel = OnboardingViewModel(permissions: FakePermissions())
        #expect(viewModel.page == .limit)
        #expect(viewModel.limit == 8)
        #expect(viewModel.primaryTitle == "다음")
        #expect(!viewModel.canSkip)
    }

    @Test func next_walksFourPages() {
        let viewModel = OnboardingViewModel(permissions: FakePermissions())
        viewModel.next()
        #expect(viewModel.page == .bothDevices)
        #expect(viewModel.canSkip)
        viewModel.next()
        #expect(viewModel.page == .toastMode)
        viewModel.next()
        #expect(viewModel.page == .permission)
        #expect(viewModel.isLastPage)
        #expect(viewModel.primaryTitle == "시작하기")
        #expect(!viewModel.canSkip)
        viewModel.next()
        #expect(viewModel.page == .permission)
    }

    @Test func skip_jumpsToPermissionPage() {
        let viewModel = OnboardingViewModel(permissions: FakePermissions())
        viewModel.next()
        viewModel.skip()
        #expect(viewModel.page == .permission)
    }

    @Test func setLimit_clampsToHalfStepsBetween1And30() {
        let viewModel = OnboardingViewModel(permissions: FakePermissions())
        viewModel.setLimit(0)
        #expect(viewModel.limit == 1)
        viewModel.setLimit(40)
        #expect(viewModel.limit == 30)
        viewModel.setLimit(5.3)
        #expect(viewModel.limit == 5.5)
        viewModel.setLimit(.nan)
        #expect(viewModel.limit == 8)
    }

    @Test func permissionsAskedOnlyWhenRequested() async {
        let permissions = FakePermissions()
        let viewModel = OnboardingViewModel(permissions: permissions)
        viewModel.next(); viewModel.next(); viewModel.next()
        #expect(permissions.notificationCalls == 0)
        #expect(permissions.locationCalls == 0)
        #expect(viewModel.notification == .notAsked)

        await viewModel.requestNotifications()
        await viewModel.requestLocation()
        #expect(permissions.notificationCalls == 1)
        #expect(permissions.locationCalls == 1)
        #expect(viewModel.notification == .granted)
        #expect(viewModel.location == .denied)
    }
}
