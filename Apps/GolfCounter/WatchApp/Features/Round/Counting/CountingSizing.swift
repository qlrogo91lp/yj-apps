import CoreGraphics

/// 카운터 세로 1페이지를 워치 화면 높이에 맞추기 위한 크기 세트 (spec §10).
///
/// `ScoringView`의 `ViewThatFits`가 regular → compact → tight 순으로 시도해
/// 실제로 들어가는 첫 세트를 고른다. **기기 모델을 분기하지 않는다** — 측정은 SwiftUI가 하므로
/// 여기에 화면 높이나 기기 이름이 등장할 이유가 없다.
///
/// 세로 합계 = headerHeight + spacing + outerRadius*2 + spacing + modeHeight.
/// `StrokeRing`이 실제로 프레임을 잡는 값은 ringDiameter가 아니라 outerRadius*2다 —
/// 초과 링이 비어 있어도 그 공간을 항상 예약하기 때문이다. `ringDiameter`는 그 역산 입력값이다.
/// 취소와 Par가 둘 다 헤더 안에 들어가므로 세로 예산에서 이 둘의 몫은 headerHeight 하나뿐이다.
struct CountingSizing {
    // MARK: 상단 정보행

    let headerHeight: CGFloat
    let headerFont: CGFloat
    let parButtonSize: CGFloat
    let undoSize: CGFloat
    /// 참이면 헤더 가운데를 "7번 홀 · 41타" 대신 "H7 · 41타"로 축약한다.
    /// 40mm에서 양끝 원형 버튼을 뺀 가운데 폭이 전체 표기보다 좁기 때문이다.
    let usesShortHoleLabel: Bool

    // MARK: 링

    let ringDiameter: CGFloat
    let ringStroke: CGFloat
    let overflowStroke: CGFloat
    /// 주 링 바깥면과 초과 링 안쪽면 사이 간격.
    let overflowGap: CGFloat
    let scoreFont: CGFloat
    let relativeFont: CGFloat

    // MARK: 하단 조작행

    let arrowSize: CGFloat
    let modeHeight: CGFloat
    /// 알약 변형의 고정 폭. `ViewThatFits`가 이 폭으로 먼저 시도하고 안 들어가면 원형으로 떨어진다.
    let modeWideWidth: CGFloat

    let spacing: CGFloat

    /// 초과 링까지 포함한 실제 반지름. 화면 폭 안에 들어가는지 판단하는 값이다.
    var outerRadius: CGFloat {
        ringDiameter / 2 + ringStroke / 2 + overflowGap + overflowStroke
    }

    /// 링 안쪽 원반 지름 — 스트로크 입력 탭 타깃이다.
    var innerDiameter: CGFloat {
        ringDiameter - ringStroke
    }

    /// 46mm 이상.
    static let regular = CountingSizing(headerHeight: 36,
                                       headerFont: 14,
                                       parButtonSize: 36,
                                       undoSize: 36,
                                       usesShortHoleLabel: false,
                                       ringDiameter: 103,
                                       ringStroke: 11,
                                       overflowStroke: 5,
                                       overflowGap: 4,
                                       scoreFont: 40,
                                       relativeFont: 13,
                                       arrowSize: 40,
                                       modeHeight: 48,
                                       modeWideWidth: 100,
                                       spacing: 6)

    /// 42~44mm.
    static let compact = CountingSizing(headerHeight: 32,
                                       headerFont: 13,
                                       parButtonSize: 32,
                                       undoSize: 32,
                                       usesShortHoleLabel: false,
                                       ringDiameter: 84,
                                       ringStroke: 10,
                                       overflowStroke: 4.5,
                                       overflowGap: 3.5,
                                       scoreFont: 33,
                                       relativeFont: 12,
                                       arrowSize: 36,
                                       modeHeight: 44,
                                       modeWideWidth: 92,
                                       spacing: 5)

    /// 40mm. `ViewThatFits`가 시도하는 마지막 후보라 이 아래로는 fallback이 없다 —
    /// 더 작은 기기가 나오거나 고정 pt 대신 Dynamic Type으로 바꿔서 이 세트도 안 맞게 되면
    /// graceful degradation 없이 콘텐츠가 잘린다. 그런 변경이 생기면 다시 실측해야 한다.
    static let tight = CountingSizing(headerHeight: 28,
                                     headerFont: 12,
                                     parButtonSize: 28,
                                     undoSize: 28,
                                     usesShortHoleLabel: true,
                                     ringDiameter: 70,
                                     ringStroke: 8,
                                     overflowStroke: 4,
                                     overflowGap: 3,
                                     scoreFont: 28,
                                     relativeFont: 11,
                                     arrowSize: 32,
                                     modeHeight: 38,
                                     modeWideWidth: 84,
                                     spacing: 4)
}
