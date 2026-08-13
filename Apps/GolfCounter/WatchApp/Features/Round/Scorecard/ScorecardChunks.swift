/// 스코어카드를 세로 페이지로 나누는 규칙 (spec §4).
///
/// 페이지 안에 스크롤을 두지 않기 위해 9홀씩 끊는다. 9홀은 골프가 원래 쓰는
/// 전반/후반 단위라 기술적 타협이 아니라 도메인에 맞는 분할이다.
/// UI 프레임워크를 import하지 않는다 — 순수 계산이다.
enum ScorecardChunks {
    static let holesPerPage = 9

    /// 0-based 홀 인덱스를 `holesPerPage` 단위로 끊은 범위 배열.
    static func ranges(holeCount: Int) -> [Range<Int>] {
        guard holeCount > 0 else { return [] }
        return stride(from: 0, to: holeCount, by: holesPerPage).map { start in
            start ..< min(start + holesPerPage, holeCount)
        }
    }
}
