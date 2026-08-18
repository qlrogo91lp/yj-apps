import CoreGraphics

/// 스코어카드 한 페이지(2열 × 5행 격자)를 워치 화면에 맞추기 위한 크기 세트.
///
/// `ScoringView`의 `ViewThatFits`가 regular → compact → tight 순으로 시도한다.
/// `CountingSizing`과 같은 접근이다 — 기기 모델을 분기하지 않고 SwiftUI가 측정한다.
///
/// 세로 합계 = headerFont lineHeight + gap*2 + Divider(1) + rowHeight*5 + 구분선(1)*4.
/// rowHeight = max(badgeDiameter, valueFont lineHeight) + rowPadding*2.
struct ScorecardSizing {
    /// 헤더("44 +8")와 타수 셀 오버파에 쓰는 폰트.
    let headerFont: CGFloat
    /// 셀의 타수 폰트.
    let valueFont: CGFloat
    /// 홀 번호 원형 배지의 지름.
    let badgeDiameter: CGFloat
    /// 배지 안 숫자 폰트.
    let badgeFont: CGFloat
    /// 각 행 위아래 패딩. `rowHeight`에 두 번(위·아래) 들어간다.
    let rowPadding: CGFloat
    /// 헤더-Divider, Divider-격자 사이 간격. 격자 안 행 사이 구분선은 별도로 1pt 고정이다.
    let gap: CGFloat
    /// 오버파 열의 고정 폭 — 이 폭을 기준으로 오른쪽 정렬해 숫자가 홀마다 나란히 줄맞는다.
    /// `+5`(파5에서 10타) 기준이고, 그보다 긴 극단값은 `minimumScaleFactor`로 흡수한다.
    let relativeColumnWidth: CGFloat

    /// 46mm 이상 (46mm · Ultra 49mm). 세로 예산 167.5pt, 가로 예산 200pt(46mm 208pt 기준
    /// 안쪽 패딩 감안). 세로 합계 163pt(여유 4.5) · 셀 폭 여유 11.8pt (실측 2026-08-18).
    static let regular = ScorecardSizing(headerFont: 17,
                                         valueFont: 15,
                                         badgeDiameter: 19,
                                         badgeFont: 11,
                                         rowPadding: 3,
                                         gap: 6,
                                         relativeColumnWidth: 20)

    /// 42mm · 44mm. 세로 예산 152pt. 세로 합계 137pt(여유 15) · 셀 폭 여유 8.4pt.
    static let compact = ScorecardSizing(headerFont: 16,
                                         valueFont: 14,
                                         badgeDiameter: 17,
                                         badgeFont: 10,
                                         rowPadding: 2,
                                         gap: 4,
                                         relativeColumnWidth: 19)

    /// 40mm. `ViewThatFits`의 마지막 후보라 이 아래로는 fallback이 없다. 세로 예산 138.5pt.
    /// 세로 합계 129pt(여유 9.5) · 셀 폭 여유 4.6pt (오버파 극단값은 `minimumScaleFactor`가 흡수).
    static let tight = ScorecardSizing(headerFont: 15,
                                       valueFont: 13,
                                       badgeDiameter: 15,
                                       badgeFont: 9,
                                       rowPadding: 2,
                                       gap: 3,
                                       relativeColumnWidth: 18)
}
