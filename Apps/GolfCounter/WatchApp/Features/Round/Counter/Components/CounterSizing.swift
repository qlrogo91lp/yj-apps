import CoreGraphics

/// 카운터 세로 1페이지를 워치 화면 높이에 맞추기 위한 크기 세트.
///
/// `CounterView`의 `ViewThatFits`가 regular → compact → tight 순으로 시도해
/// 실제로 들어가는 첫 세트를 고른다. **기기 모델을 분기하지 않는다** — 측정은 SwiftUI가 하므로
/// 여기에 화면 높이나 기기 이름이 등장할 이유가 없다.
struct CounterSizing {
    let headerFont: CGFloat
    let scoreFont: CGFloat
    let strokeButton: CGFloat
    let strokeIcon: CGFloat
    /// 모드 토글과 Par 버튼의 높이.
    let controlHeight: CGFloat
    /// 홀 이동 버튼의 높이.
    let navHeight: CGFloat
    let spacing: CGFloat

    /// 46mm 이상. 기존 레이아웃 값 그대로다.
    static let regular = CounterSizing(headerFont: 15,
                                       scoreFont: 22,
                                       strokeButton: 62,
                                       strokeIcon: 26,
                                       controlHeight: 28,
                                       navHeight: 30,
                                       spacing: 8)

    /// 42~44mm.
    static let compact = CounterSizing(headerFont: 14,
                                       scoreFont: 20,
                                       strokeButton: 54,
                                       strokeIcon: 23,
                                       controlHeight: 26,
                                       navHeight: 28,
                                       spacing: 6)

    /// 40mm. 타수 버튼이 최소 탭 타깃(44pt)에 가장 가까워지는 세트다.
    ///
    /// `ViewThatFits`가 시도하는 마지막 후보라 이 아래로는 더 이상의 fallback이 없다 —
    /// 더 작은 기기가 새로 나오거나 고정 pt 대신 scalable/Dynamic Type 폰트로 바꿔서
    /// `.tight`도 안 맞게 되면 graceful degradation 없이 콘텐츠가 잘리거나 넘친다.
    /// 그런 변경이 생기면 이 크기 세트를 다시 실측해야 한다.
    static let tight = CounterSizing(headerFont: 13,
                                     scoreFont: 18,
                                     strokeButton: 46,
                                     strokeIcon: 20,
                                     controlHeight: 24,
                                     navHeight: 26,
                                     spacing: 4)
}
