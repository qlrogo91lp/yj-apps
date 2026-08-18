import CoreGraphics

/// 스코어카드 한 페이지(2열 × 5행 격자)를 워치 화면에 맞추기 위한 크기 세트.
///
/// `ScoringView`의 `ViewThatFits`가 regular → compact → tight 순으로 시도한다.
/// `CountingSizing`과 같은 접근이다 — 기기 모델을 분기하지 않고 SwiftUI가 측정한다.
///
/// 세로 합계 = headerFont lineHeight + gap*2 + Divider(1) + rowHeight*5 + 구분선(1)*4.
struct ScorecardSizing {
    /// 헤더("Total: 44 +8")와 타수 셀 오버파에 쓰는 폰트.
    let headerFont: CGFloat
    /// 셀의 타수 폰트.
    let valueFont: CGFloat
    /// 홀 번호 원형 배지의 지름.
    let badgeDiameter: CGFloat
    /// 배지 안 숫자 폰트.
    let badgeFont: CGFloat
    /// 격자 한 행의 **고정** 높이 — `max(badgeDiameter, valueFont lineHeight) + 위아래 여백`으로
    /// 정한 실측값이다.
    ///
    /// 고정해야 하는 이유: 행 안의 세로 `Divider`는 축에 수직으로 최대한 늘어나려 하므로,
    /// 높이를 비워 두면 `VStack`이 남는 공간을 행들에 나눠 준다. 그러면 **홀이 적은 페이지일수록
    /// 행이 세로로 벌어져** 페이지마다 레이아웃이 달라진다 (2026-08-18 시뮬레이터 확인).
    let rowHeight: CGFloat
    /// 헤더-Divider, Divider-격자 사이 간격. 격자 안 행 사이 구분선은 별도로 1pt 고정이다.
    /// `Spacer`가 아니라 고정 높이로 넣는다 — 같은 이유로 페이지마다 간격이 달라지면 안 된다.
    let gap: CGFloat
    /// 오버파 열의 고정 폭 — 이 폭을 기준으로 오른쪽 정렬해 숫자가 홀마다 나란히 줄맞는다.
    /// `+5`(파5에서 10타) 기준이고, 그보다 긴 극단값은 `minimumScaleFactor`로 흡수한다.
    let relativeColumnWidth: CGFloat

    /// 홀 배지와 타수 사이 간격. 붙어 있으면 배지 숫자와 타수가 한 덩어리로 읽힌다.
    static let badgeSpacing: CGFloat = 8

    /// 셀 좌우 안쪽 여백. 가운데 세로 구분선에 오버파가 달라붙지 않게 한다.
    /// 셀마다 좌우로 들어가므로 한 행에서 이 값의 네 배가 소모된다 —
    /// 40mm(가장 빡빡한 tight 세트) 기준 셀 폭 여유 2.8pt를 남기는 값이다 (실측 2026-08-18).
    static let cellPadding: CGFloat = 4

    /// 타수와 오버파 사이 최소 간격. 둘 사이는 `Spacer`가 벌리지만, 값이 길어져 공간이
    /// 없을 때도 이만큼은 남긴다.
    static let valueSpacing: CGFloat = 2

    /// 46mm 이상 (46mm · Ultra 49mm). 세로 예산 167.5pt.
    /// 세로 합계 163pt(여유 4.5) · 셀 폭 여유 16.3pt (실측 2026-08-18).
    static let regular = ScorecardSizing(headerFont: 17,
                                         valueFont: 15,
                                         badgeDiameter: 19,
                                         badgeFont: 11,
                                         rowHeight: 25,
                                         gap: 6,
                                         relativeColumnWidth: 20)

    /// 42mm · 44mm. 세로 예산 152pt. 세로 합계 137pt(여유 15) · 셀 폭 여유 9.8pt.
    static let compact = ScorecardSizing(headerFont: 16,
                                         valueFont: 14,
                                         badgeDiameter: 17,
                                         badgeFont: 10,
                                         rowHeight: 21,
                                         gap: 4,
                                         relativeColumnWidth: 19)

    /// 40mm. `ViewThatFits`의 마지막 후보라 이 아래로는 fallback이 없다. 세로 예산 138.5pt.
    /// 세로 합계 129pt(여유 9.5) · 셀 폭 여유 2.8pt (오버파 극단값은 `minimumScaleFactor`가 흡수).
    static let tight = ScorecardSizing(headerFont: 15,
                                       valueFont: 13,
                                       badgeDiameter: 15,
                                       badgeFont: 9,
                                       rowHeight: 20,
                                       gap: 3,
                                       relativeColumnWidth: 18)
}
