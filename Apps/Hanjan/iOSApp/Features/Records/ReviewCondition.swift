import Foundation

/// 다음 날 회고의 상태 5단계. 저장 값은 1...5. 글자만 쓰고 이모지는 쓰지 않는다.
enum ReviewCondition {
    static let labels = ["멀쩡", "기분 좋음", "취함", "많이 취함", "필름 끊김"]
    static let values = Array(1 ... labels.count)

    static func label(_ value: Int?) -> String? {
        guard let value, labels.indices.contains(value - 1) else { return nil }
        return labels[value - 1]
    }
}
