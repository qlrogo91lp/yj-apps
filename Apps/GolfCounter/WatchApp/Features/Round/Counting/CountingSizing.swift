import CoreGraphics

/// 카운터 세로 1페이지를 워치 화면에 맞추기 위한 크기 세트 (spec §10).
///
/// `ScoringView`의 `ViewThatFits`가 regular → compact → tight 순으로 시도해
/// 실제로 들어가는 첫 세트를 고른다. **기기 모델을 분기하지 않는다** — 측정은 SwiftUI가 하므로
/// 여기에 화면 높이나 기기 이름이 등장할 이유가 없다.
///
/// 레이아웃은 두 행이다: 헤더(Par · 홀·타수 텍스트 · 모드) + 링 존(◁ 링 ▷).
/// 헤더와 링 사이는 `Spacer`가 메운다 — 고정 간격이 아니라 세로 예산의 남는 몫을
/// 그대로 여백으로 돌려준다. 취소는 이 세로 스택 밖, 화면 왼쪽 아래 코너에 오버레이로
/// 뜬다 — 등장·퇴장이 레이아웃을 밀어내지 않고, 링 크기와도 다투지 않는다.
///
/// 세로 합계 = headerButtonSize + spacing(Spacer 최소값) + outerRadius*2.
/// 가로 합계 = arrowSize*2 + spacing*2 + outerRadius*2.
/// `StrokeRing`이 실제로 프레임을 잡는 값은 ringDiameter가 아니라 outerRadius*2다 —
/// 초과 링이 비어 있어도 그 공간을 항상 예약하기 때문이다. `ringDiameter`는 그 역산 입력값이다.
struct CountingSizing {

    // MARK: 헤더 행

    /// Par·모드가 공유하는 원형 지름. 헤더 행 높이도 이 값이다.
    let headerButtonSize: CGFloat
    /// Par 버튼 숫자 폰트.
    let headerFont: CGFloat
    /// 헤더 가운데 "Hole 7 · 41" 텍스트 폰트.
    let holeInfoFont: CGFloat

    // MARK: 링 존

    /// 이전/다음 홀 화살표 원형 지름. 직접 누르는 탭 타깃이라 시각 크기를 줄이지
    /// 않는다 — regular·compact는 헤더 버튼과 같은 크기이고, tight(40mm)만 가로
    /// 폭 한계 때문에 살짝 작다 (아래 tight 세트 주석 참조).
    let arrowSize: CGFloat

    let ringDiameter: CGFloat
    let ringStroke: CGFloat
    let overflowStroke: CGFloat
    /// 주 링 바깥면과 초과 링 안쪽면 사이 간격.
    let overflowGap: CGFloat

    // MARK: 링 중앙 텍스트

    /// 링 중앙 두 줄 — 이 홀 타수 · 파 대비. 홀 번호·누적 타수는 헤더로 옮겨갔으므로
    /// 여기 남는 건 이 둘뿐이라 폰트를 더 키울 수 있다.
    let scoreFont: CGFloat
    let relativeFont: CGFloat

    /// 화살표-링 가로 간격, 헤더-링 세로 `Spacer`의 최소 간격을 겸한다.
    let spacing: CGFloat

    /// 참이면 헤더 가운데 텍스트를 "Hole 18 · 108" 대신 "H18 · 108"로 축약한다.
    /// 40mm에서만 켠다 — 18홀 후반(홀 두 자리 + 누적 세 자리)이 그 세트에서만
    /// 페이지 인디케이터를 피한 뒤 남는 폭보다 커질 수 있기 때문이다.
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
    /// `TabView(.verticalPage)`의 세로 페이지 인디케이터가 화면 오른쪽 끝, 헤더와 같은
    /// 높이에 그려진다 — 42mm 실측 기준 오른쪽 가장자리에서 약 7pt를 차지하고, 우리 뷰
    /// 위에 덮어 그리므로 헤더 오른쪽 끝 요소가 거기까지 뻗으면 잘려 보인다.
    /// 크기 세트가 아니라 시스템 크롬의 상수라 세트별로 나누지 않는다.
    /// 링 존은 이 값을 쓰지 않는다 — 화살표는 인디케이터보다 아래에 있어 겹치지 않는다.
    static let pageIndicatorInset: CGFloat = 12

    /// 링 존이 화면 좌우에서 물러나는 거리. 헤더(`pageIndicatorInset`)보다 작다 —
    /// 화살표는 페이지 인디케이터와 겹치지 않아 링에 폭을 더 내준다.
    static let ringHorizontalPadding: CGFloat = 4

    /// Par·모드 원형의 탭 영역을 시각 크기 밖으로 균일하게 넓히는 값.
    /// 양옆 이웃(화면 여백, 헤더 가운데 텍스트)이 전부 비조작 요소라 어느 방향으로
    /// 넓혀도 다른 탭을 가로챌 위험이 없다 — `.contentShape`만 키우므로 양끝 버튼
    /// 사이 텍스트 폭 예산(레이아웃)에는 영향이 없다.
    static let headerButtonHitInset: CGFloat = 5

    /// 취소(코너 오버레이)의 탭 영역 확장값. 헤더 버튼보다 여유를 더 준다 —
    /// 코너 배치라 사방 중 세 방향(아래·왼쪽 화면 모서리, 위쪽 화살표와의 넉넉한 간격)이
    /// 전부 비어 있다.
    static let undoHitInset: CGFloat = 8

    /// 취소를 `ringArea`의 레이아웃 경계보다 더 아래로 내리는 오프셋.
    ///
    /// `ringArea`는 `arrowHitHeight`와 링 높이 중 큰 쪽으로 세로 크기가 정해지는데,
    /// 그 바닥은 화살표의 세로 중앙보다 한참 아래다. 취소를 굳이 더 내리는 이유는
    /// `‹`와의 시각적 간격을 벌리기 위해서다 — 링 존의 레이아웃 경계를 넘어서는
    /// 값이지만, `TabView(.verticalPage)`는 페이지 콘텐츠를 잘라내지 않는다.
    ///
    /// 30이었을 때 40mm에서 화면 바닥에 실제로 잘렸다(실기 확인, 2026-08-15) — 세
    /// 크기 세트 중 세로 여유가 가장 적은 게 40mm라, 값을 하나만 쓰려면 그 세트가
    /// 상한을 정한다. 26으로 낮춰 40mm 기준 약 4pt 여백을 남겼다(42/46/49mm은
    /// 그보다 여유가 더 크다).
    static let undoBottomOffset: CGFloat = 26

    /// 화살표의 세로 히트 영역. 시각 크기(`arrowSize`)보다 훨씬 크다 — 링 존의 세로
    /// 공간이 화살표보다 넉넉히 남기 때문에(가장 작은 tight도 100pt) 위아래로 여유
    /// 있게 키워도 링과 다투지 않는다. **가로는 넓히지 않는다** — 옆이 바로 링(가장
    /// 자주 쓰는 탭 타깃)이라 침범하면 스트로크 탭을 가로챌 위험이 있다.
    static let arrowHitHeight: CGFloat = 60

    /// 46mm 이상 (46mm · Ultra 49mm).
    ///
    /// 세로 예산은 `GeometryReader` 실측 기준 약 167.5pt(46mm) — 중첩 TabView 크롬이
    /// 화면 높이를 상당히 잠식하기 때문에 화면 높이를 그대로 쓰면 안 된다.
    /// 이 세트의 가장 좁은 기기는 Ultra(211pt)가 아니라 46mm(208pt)다 — 폭은 mm 순서를
    /// 따르지 않는다. 패딩 8을 뺀 200pt가 가로 예산.
    ///
    /// `arrowSize`를 `headerButtonSize`와 맞추면서(2026-08-15, 직접 탭하는 요소라
    /// 축소하지 않기로 함) 그만큼 링이 줄었다 — `ringDiameter` 98→90, 링 스트로크는
    /// 그대로라 손해 없음. 세로 합계 156pt(여유 11.5) · 가로 합계 198pt(여유 2).
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
    ///
    /// `arrowSize`를 `headerButtonSize`와 맞추려면 링 스트로크를 살짝 얇혀야 폭이
    /// 맞는다(9→8, 오버플로 3.5→3, 갭 2.5→2) — 탭 원반(`innerDiameter`)은 여전히
    /// 70pt 이상(72pt)을 지킨다. 세로 합계 136pt(여유 16) · 가로 합계 174pt(여유 2).
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

    /// 40mm. `ViewThatFits`가 시도하는 마지막 후보라 이 아래로는 fallback이 없다 —
    /// 더 작은 기기가 나오거나 고정 pt 대신 Dynamic Type으로 바꿔서 이 세트도 안 맞게 되면
    /// graceful degradation 없이 콘텐츠가 잘린다. 그런 변경이 생기면 다시 실측해야 한다.
    /// 가로 예산 154pt(폭 162 − 패딩 8). `usesShortHoleLabel`로 헤더 텍스트를 축약해
    /// 확보한 여유를 `holeInfoFont`에 썼다.
    ///
    /// **`arrowSize`는 `headerButtonSize`(30)와 완전히 같아지지 못한다** — 그러려면
    /// 링 스트로크를 5pt대까지 깎아야 하는데(오버플로·갭도 1pt대), 그러면 색 구분이
    /// 흐려지고 다른 세트와 스트로크 두께가 크게 어긋난다. 대신 25로, regular·compact
    /// 대비 여전히 눈에 띄게 커졌다(22→25). 스트로크는 8→7·3→2.5·2→1.5로만 살짝
    /// 얇혔다. 세로 합계 128pt(여유 10.5) · 가로 합계 152pt(여유 2).
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
