import CoreGraphics

/// 카운터 세로 1페이지를 워치 화면에 맞추기 위한 크기 세트 (spec §10).
///
/// `ScoringView`의 `ViewThatFits`가 regular → compact → tight 순으로 시도한다.
/// **기기 모델을 분기하지 않는다** — 측정은 SwiftUI가 한다.
///
/// 세로 합계 = headerButtonSize + spacing(Spacer 최소값) + outerRadius*2.
/// 가로 합계 = arrowSize*2 + spacing*2 + outerRadius*2 — 링이 실제로 잡는 프레임은
/// ringDiameter가 아니라 outerRadius*2다(초과 링 공간을 항상 예약한다).
struct CountingSizing {

    // MARK: 헤더 행

    /// Par·모드가 공유하는 원형 지름. 헤더 행 높이도 이 값이다.
    let headerButtonSize: CGFloat
    /// Par 버튼 숫자 폰트.
    let headerFont: CGFloat
    /// 헤더 가운데 "Hole 7 · 41" 텍스트 폰트.
    let holeInfoFont: CGFloat

    // MARK: 링 존

    /// 이전/다음 홀 화살표 원형 지름. 직접 누르는 탭 타깃이라 줄이지 않는다 —
    /// regular·compact는 헤더 버튼과 같고, tight(40mm)만 가로 폭 한계로 살짝 작다.
    let arrowSize: CGFloat

    let ringDiameter: CGFloat
    let ringStroke: CGFloat
    let overflowStroke: CGFloat
    /// 주 링 바깥면과 초과 링 안쪽면 사이 간격.
    let overflowGap: CGFloat

    // MARK: 링 중앙 텍스트

    /// 링 중앙 두 줄 — 이 홀 타수 · 파 대비.
    let scoreFont: CGFloat
    let relativeFont: CGFloat

    /// 화살표-링 가로 간격, 헤더-링 세로 `Spacer`의 최소 간격을 겸한다.
    let spacing: CGFloat

    /// 참이면 헤더 가운데 텍스트를 "Hole 18 · 108" 대신 "H18 · 108"로 축약한다.
    /// 40mm에서만 켠다 — 18홀 후반 표기가 그 세트에서만 남는 폭을 넘길 수 있다.
    let usesShortHoleLabel: Bool

    /// 초과 링까지 포함한 실제 반지름. 예산 안에 들어가는지 판단하는 값이다.
    var outerRadius: CGFloat {
        ringDiameter / 2 + ringStroke / 2 + overflowGap + overflowStroke
    }

    /// 링 안쪽 원반 지름 — 스트로크 입력 탭 타깃이다.
    var innerDiameter: CGFloat {
        ringDiameter - ringStroke
    }

    /// 헤더 행이 화면 좌우에서 물러나야 하는 거리.
    ///
    /// `TabView(.verticalPage)`의 세로 페이지 인디케이터가 헤더와 같은 높이에 덮어 그려진다 —
    /// 42mm 실측 기준 오른쪽 가장자리에서 약 7pt. 시스템 크롬 상수라 세트별로 나누지 않고,
    /// 링 존은 쓰지 않는다(화살표는 인디케이터보다 아래다).
    ///
    /// **세로 인디케이터는 가로와 달리 safe area에 잡히지 않는다** — 좌우 inset이 2pt뿐이라
    /// 직접 피해야 한다. 하단 가로 인디케이터는 반대로 safe area가 처리한다 (실측 2026-08-17).
    static let pageIndicatorInset: CGFloat = 12

    /// 링 존이 화면 좌우에서 물러나는 거리. 헤더(`pageIndicatorInset`)보다 작다 —
    /// 화살표는 페이지 인디케이터와 겹치지 않아 링에 폭을 더 내준다.
    static let ringHorizontalPadding: CGFloat = 4

    /// Par·모드 원형의 탭 영역을 시각 크기 밖으로 균일하게 넓히는 값.
    /// 양옆 이웃이 전부 비조작 요소라 어느 방향으로 넓혀도 다른 탭을 가로채지 않는다.
    static let headerButtonHitInset: CGFloat = 5

    /// 취소(코너 오버레이)의 탭 영역 확장값. 코너 배치라 사방 중 세 방향이 비어 있어
    /// 헤더 버튼보다 여유를 더 준다.
    static let undoHitInset: CGFloat = 8

    /// 취소를 `ringArea`의 레이아웃 경계보다 더 아래로 내리는 오프셋 — `‹`와의 간격을
    /// 벌리기 위해서다. 경계를 넘지만 `TabView(.verticalPage)`는 콘텐츠를 잘라내지 않는다.
    ///
    /// 30이었을 때 40mm에서 화면 바닥에 잘렸다(실기 확인, 2026-08-15). 세로 여유가 가장
    /// 적은 40mm가 상한을 정한다 — 26이면 그 기준 약 4pt 여백이 남는다.
    static let undoBottomOffset: CGFloat = 26

    /// 화살표의 세로 히트 영역. 링 존의 세로 공간이 넉넉해(가장 작은 tight도 100pt)
    /// 위아래로 키워도 링과 다투지 않는다. **가로는 넓히지 않는다** — 옆이 바로 링이라
    /// 침범하면 스트로크 탭을 가로챈다.
    static let arrowHitHeight: CGFloat = 60

    /// 46mm 이상 (46mm · Ultra 49mm).
    ///
    /// 세로 예산 167.5pt — 화면 248에서 safe area(위 44.5 · 아래 36)를 뺀 값이다.
    /// 중첩 TabView 자체는 세로를 먹지 않는다 — 단일/중첩 측정값이 같다 (실측 2026-08-17).
    /// 가로 예산 200pt — 이 세트의 가장 좁은 기기는 Ultra(211pt)가 아니라 46mm(208pt)다.
    /// 세로 합계 156pt(여유 11.5) · 가로 합계 198pt(여유 2).
    static let regular = CountingSizing(headerButtonSize: 36,
                                        headerFont: 16,
                                        holeInfoFont: 15,
                                        arrowSize: 36,
                                        ringDiameter: 90,
                                        ringStroke: 10,
                                        overflowStroke: 4,
                                        overflowGap: 3,
                                        scoreFont: 40,
                                        relativeFont: 13,
                                        spacing: 6,
                                        usesShortHoleLabel: false)

    /// 42mm · 44mm. 가장 좁은 44mm(폭 184pt) 기준 가로 예산 176pt.
    /// 탭 원반(`innerDiameter`)은 70pt 이상(72pt)을 지킨다.
    /// 세로 합계 136pt(여유 16) · 가로 합계 174pt(여유 2).
    static let compact = CountingSizing(headerButtonSize: 33,
                                        headerFont: 15,
                                        holeInfoFont: 14,
                                        arrowSize: 33,
                                        ringDiameter: 80,
                                        ringStroke: 8,
                                        overflowStroke: 3,
                                        overflowGap: 2,
                                        scoreFont: 34,
                                        relativeFont: 12,
                                        spacing: 5,
                                        usesShortHoleLabel: false)

    /// 40mm. 가로 예산 154pt(폭 162 − 패딩 8). `ViewThatFits`의 마지막 후보라 이 아래로는
    /// fallback이 없다 — 더 작은 기기나 Dynamic Type 전환이 생기면 다시 실측해야 한다.
    ///
    /// **`arrowSize`는 `headerButtonSize`(30)까지 못 키운다** — 링 스트로크를 5pt대까지
    /// 깎아야 해서 색 구분이 흐려진다. 세로 합계 128pt(여유 10.5) · 가로 합계 152pt(여유 2).
    static let tight = CountingSizing(headerButtonSize: 30,
                                      headerFont: 13,
                                      holeInfoFont: 13,
                                      arrowSize: 25,
                                      ringDiameter: 79,
                                      ringStroke: 7,
                                      overflowStroke: 2.5,
                                      overflowGap: 1.5,
                                      scoreFont: 30,
                                      relativeFont: 11,
                                      spacing: 4,
                                      usesShortHoleLabel: true)
}
