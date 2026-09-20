import Foundation

/// 농도 기준. **어떤 값으로 재고 어디서 끊을지**를 함께 들고 있다.
///
/// 값 추출을 주입받으므로 `level(for:)` 이 `WorkoutSource` 를 **아예 보지 않는다** (스펙 4.4).
/// `source == .manual` 이면 무조건 최소 농도로 읽으면 틀린 값이 나온다 — 08 수동 기록은
/// 사용자가 시간을 직접 입력하고, 90분을 손으로 넣었는데 1단계로 찍히면 fallback 이 아니라
/// 버그다. 반대로 칼로리 기준으로 전환하면 수동 기록엔 칼로리가 없어 자연히 1단계로 떨어진다 —
/// 제품 스펙 D4 의 괄호가 가리키는 게 정확히 그 상황이다.
struct GrassIntensity {
    /// 농도의 입력이 되는 값. 없거나 0 이하면 최소 농도로 간다.
    let value: (DailyAggregate) -> Double?
    /// 오름차순 컷 3개. **이상/미만**으로 끊는다 — 정확히 30분은 2단계다.
    let cuts: [Double]

    /// D-M6 확정값 — 30 / 60 / 90분.
    ///
    /// 칼로리 기준 컷은 **실제 데이터가 없어 정할 근거가 없다** (스펙 9절). 여기 상수를
    /// 하나 더하는 것으로 끝나도록 자리만 열어 둔다.
    static let byTime = GrassIntensity(value: { Double($0.totalSeconds) },
                                       cuts: [1800, 3600, 5400])

    /// 레코드가 하나라도 있으면 **아무리 짧아도 1단계 이상**이다 (스펙 4.3).
    func level(for aggregate: DailyAggregate) -> GrassLevel {
        guard let value = value(aggregate), value > 0 else { return .light }
        let step = cuts.reduce(1) { $0 + (value >= $1 ? 1 : 0) }
        return GrassLevel(rawValue: step) ?? .peak
    }
}
