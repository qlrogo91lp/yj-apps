import Foundation

/// 골프 표기 관례에 맞춘 표시 문자열 포맷. 컴플리케이션과 워치 카운터가 같은 규칙을 쓴다.
enum ScoreFormat {
    /// 이븐파는 0이 아니라 E, 오버파는 명시적으로 + 부호를 붙인다.
    static func relativeToPar(_ value: Int) -> String {
        if value == 0 {
            return "E"
        }
        if value > 0 {
            return "+\(value)"
        }
        return "\(value)"
    }
}
