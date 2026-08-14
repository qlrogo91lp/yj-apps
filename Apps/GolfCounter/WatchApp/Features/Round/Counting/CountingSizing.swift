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

    /// 이전/다음 홀 화살표 원형 지름. 헤더 버튼보다 작다 — 저빈도 조작이라 시각 크기를
    /// 낮추는 대신 히트 영역만 링 옆 여백만큼 넉넉히 확장한다 (구현에서 처리).
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

    // MARK: 취소 (코너 오버레이)

    /// 화면 왼쪽 아래 코너에 뜨는 취소 버튼 지름. 헤더 버튼보다 작아도 된다 —
    /// 저빈도 교정 동작이고, 코너 배치 자체가 화면 모서리까지 히트 영역을 넓힐 수 있다.
    let undoSize: CGFloat

    /// 화살표-링 가로 간격, 헤더-링 세로 `Spacer`의 최소 간격을 겸한다.
    let spacing: CGFloat

    /// 초과 링까지 포함한 실제 반지름. 예산 안에 들어가는지 판단하는 값이다.
    var outerRadius: CGFloat {
        ringDiameter / 2 + ringStroke / 2 + overflowGap + overflowStroke
    }

    /// 링 안쪽 원반 지름 — 스트로크 입력 탭 타깃이다.
    var innerDiameter: CGFloat {
        ringDiameter - ringStroke
    }

    /// 46mm 이상 (46mm · Ultra 49mm).
    ///
    /// 세로 예산은 `GeometryReader` 실측 기준 약 167.5pt(46mm) — 중첩 TabView 크롬이
    /// 화면 높이를 상당히 잠식하기 때문에 화면 높이를 그대로 쓰면 안 된다.
    /// 가장 좁은 대상 기기인 Ultra(폭 205pt)에서 패딩 8을 뺀 197pt가 가로 예산이다.
    /// 세로 합계 162pt(여유 5.5) · 가로 합계 192pt(여유 5).
    static let regular = CountingSizing(headerButtonSize: 32,
                                        headerFont: 14,
                                        holeInfoFont: 13,
                                        arrowSize: 28,
                                        ringDiameter: 100,
                                        ringStroke: 10,
                                        overflowStroke: 4,
                                        overflowGap: 3,
                                        scoreFont: 40,
                                        relativeFont: 13,
                                        undoSize: 30,
                                        spacing: 6)

    /// 41~45mm. 가장 좁은 41mm(폭 176pt) 기준 가로 예산 168pt.
    /// 세로 합계 142pt(여유 10) · 가로 합계 166pt(여유 2).
    static let compact = CountingSizing(headerButtonSize: 28,
                                        headerFont: 13,
                                        holeInfoFont: 12,
                                        arrowSize: 24,
                                        ringDiameter: 87,
                                        ringStroke: 9,
                                        overflowStroke: 3.5,
                                        overflowGap: 2.5,
                                        scoreFont: 34,
                                        relativeFont: 12,
                                        undoSize: 26,
                                        spacing: 5)

    /// 40mm. `ViewThatFits`가 시도하는 마지막 후보라 이 아래로는 fallback이 없다 —
    /// 더 작은 기기가 나오거나 고정 pt 대신 Dynamic Type으로 바꿔서 이 세트도 안 맞게 되면
    /// graceful degradation 없이 콘텐츠가 잘린다. 그런 변경이 생기면 다시 실측해야 한다.
    /// 가로 예산 154pt(폭 162 − 패딩 8). 세로 합계 130pt(여유 8.5) · 가로 합계 152pt(여유 2).
    static let tight = CountingSizing(headerButtonSize: 26,
                                      headerFont: 12,
                                      holeInfoFont: 11,
                                      arrowSize: 22,
                                      ringDiameter: 82,
                                      ringStroke: 8,
                                      overflowStroke: 3,
                                      overflowGap: 2,
                                      scoreFont: 30,
                                      relativeFont: 11,
                                      undoSize: 24,
                                      spacing: 4)
}
