import Foundation

struct RecordDetailSummary {
    let dateTitle: String
    let timeRangeTitle: String
    let durationText: String
    let caloriesText: String
    let heartRateText: String
    let spans: [Span]
    let compositionText: String?

    struct Span: Hashable {
        let kind: SegmentKind
        let seconds: Int
    }
}
