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
        case .saveFailed: "워치 기록을 저장하지 못했어요"
        case .syncFailed: "건강 앱 기록을 가져오지 못했어요"
        case .deleteFailed: "기록을 삭제하지 못했어요"
        case .editFailed: "변경 내용을 저장하지 못했어요"
        }
    }

    var message: String {
        switch self {
        // 워치 워크아웃은 건강 앱에 이미 있어 다음 import 가 구간 1개짜리 레코드로 가져온다
        case .saveFailed: "다음 동기화 때 건강 앱에서 다시 가져와요. 근력·유산소 구분은 남지 않을 수 있어요."
        case .syncFailed: "목록을 당겨서 다시 시도해 주세요."
        case .deleteFailed: "잠시 후 다시 시도해 주세요."
        case .editFailed: "잠시 후 다시 시도해 주세요."
        }
    }
}
