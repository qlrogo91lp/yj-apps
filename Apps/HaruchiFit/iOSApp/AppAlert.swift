import Foundation

/// 사용자에게 알리는 실패. 어느 탭에 있든 생길 수 있어 앱 루트가 띄운다.
enum AppAlert: String, Identifiable {
    case saveFailed
    case syncFailed
    case deleteFailed
    case editFailed

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .saveFailed: String(localized: "alert_save_failed_title")
        case .syncFailed: String(localized: "alert_sync_failed_title")
        case .deleteFailed: String(localized: "alert_delete_failed_title")
        case .editFailed: String(localized: "alert_edit_failed_title")
        }
    }

    var message: String {
        switch self {
        // 워치 워크아웃은 건강 앱에 이미 있어 다음 import 가 구간 1개짜리 레코드로 가져온다
        case .saveFailed: String(localized: "alert_save_failed_message")
        case .syncFailed: String(localized: "alert_sync_failed_message")
        case .deleteFailed, .editFailed: String(localized: "alert_retry_later")
        }
    }
}
