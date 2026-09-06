import Foundation
import SwiftData

/// 세션 안의 운동 구간 하나. 근력↔유산소 전환 한 번이 구간 하나를 닫고 다음을 연다.
///
/// **시간만 갖는다** — 구간별 칼로리·심박은 내지 않는다 (D-M3). 그 값을 쓰는 화면이 없고,
/// 내려면 구간마다 `HKStatisticsQuery` 를 돌려야 한다.
@Model
final class Segment {
    /// `SegmentKind` 의 rawValue. CloudKit 이 enum 저장을 직접 지원하지 않는다.
    var kindRaw: String = SegmentKind.strength.rawValue
    /// 워크아웃 시작으로부터의 오프셋(초). 정렬 키다.
    var startOffset: Int = 0
    var durationSeconds: Int = 0

    /// CloudKit 요구사항: optional + `WorkoutRecord.segments` 가 inverse 로 지정한다.
    var record: WorkoutRecord?

    var kind: SegmentKind {
        get { SegmentKind(rawValue: kindRaw) ?? .strength }
        set { kindRaw = newValue.rawValue }
    }

    init(kind: SegmentKind, startOffset: Int, durationSeconds: Int) {
        kindRaw = kind.rawValue
        self.startOffset = startOffset
        self.durationSeconds = durationSeconds
    }
}

/// 구간의 종류. 외부 워크아웃을 가져올 때도 이 둘 중 하나로 분류한다 (아키텍처 4.2).
enum SegmentKind: String, Codable, CaseIterable {
    case strength
    case cardio

    var title: String {
        switch self {
        case .strength: "근력"
        case .cardio: "유산소"
        }
    }
}
