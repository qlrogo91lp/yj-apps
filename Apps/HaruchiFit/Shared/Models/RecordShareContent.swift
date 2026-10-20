import Foundation
import WorkoutCore

struct RecordShareContent {
    /// 머리줄 아래 구성 막대와 종류별 시간. 1분 이상인 종류가 없으면 nil — 카드에 자리를 두지 않는다.
    struct Composition: Equatable {
        let spans: [RecordDetailSummary.Span]
        let text: String
    }

    let title: String
    let startedAt: Date
    let endedAt: Date
    let result: WorkoutResult
    let composition: Composition?
}
