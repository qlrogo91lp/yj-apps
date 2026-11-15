import Foundation

/// 온보딩 마지막 장의 권한 요청. 테스트는 가짜를 넣어 버튼을 누를 때만 묻는지 확인한다.
protocol PermissionRequesting: AnyObject {
    func requestNotifications() async -> Bool
    func requestLocation() async -> Bool
}
