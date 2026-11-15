import Combine
import Foundation

/// 첫 실행 온보딩 4장: ① 주량 ② 폰과 워치 ③ 짠 모드 ④ 알림·위치 권한.
/// 한도는 끝날 때 호출부로 넘긴다 — 저장(`AppSettings`)은 T9 가 잇는다.
final class OnboardingViewModel: ObservableObject {
    enum Page: Int, CaseIterable, Hashable {
        case limit, bothDevices, toastMode, permission
    }

    static let limitRange = 1.0 ... 30.0
    static let limitStep = 0.5
    static let defaultLimit = 8.0

    @Published var page: Page = .limit
    @Published private(set) var limit = defaultLimit
    @Published private(set) var notification: OnboardingPermissionState = .notAsked
    @Published private(set) var location: OnboardingPermissionState = .notAsked

    private let permissions: PermissionRequesting

    init(permissions: PermissionRequesting = SystemPermissionRequester()) {
        self.permissions = permissions
    }

    var isLastPage: Bool {
        page == .permission
    }

    var primaryTitle: String {
        isLastPage ? "시작하기" : "다음"
    }

    /// 설명 장(②③)만 건너뛸 수 있다. 주량은 기본값이 있어 그냥 `다음` 이면 되고, 마지막 장은 `시작하기` 가 곧 건너뛰기다.
    var canSkip: Bool {
        page == .bothDevices || page == .toastMode
    }

    func next() {
        guard let next = Page(rawValue: page.rawValue + 1) else { return }
        page = next
    }

    func skip() {
        page = .permission
    }

    /// 1~30, 0.5 단위. 숫자가 아니면 기본 8.
    func setLimit(_ value: Double) {
        guard value.isFinite else {
            limit = Self.defaultLimit
            return
        }
        let stepped = (value / Self.limitStep).rounded() * Self.limitStep
        limit = min(max(stepped, Self.limitRange.lowerBound), Self.limitRange.upperBound)
    }

    /// 버튼을 눌렀을 때만 시스템 창을 띄운다.
    func requestNotifications() async {
        notification = await permissions.requestNotifications() ? .granted : .denied
    }

    func requestLocation() async {
        location = await permissions.requestLocation() ? .granted : .denied
    }
}
