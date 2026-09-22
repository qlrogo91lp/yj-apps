import HealthKit

/// `HKWorkoutActivityType` 을 하루치 핏의 구간 종류로 옮긴다.
///
/// **표에 없는 타입은 nil 이고, nil 은 "가져오지 않는다" 는 뜻이다** (D-M5 · 스펙 2절).
/// 요가·수영·구기는 물론 `.other` · `.mixedCardio` · `.crossTraining` 도 여기 없다 —
/// 사용자가 그 안에 무엇을 넣었는지 앱이 알 수 없고, 어느 쪽으로 분류해도 절반은 틀린다.
///
/// ⚠️ **이 표를 고치면 앵커를 버리고 전체를 다시 읽어야 한다.** 앵커만 유지한 채 넓히면
/// 앞으로 들어올 워크아웃만 새 규칙을 따르고 과거는 옛 규칙에 남아, 같은 종목이 날짜에
/// 따라 다르게 보인다 (스펙 2절 "변경 시 지켜야 할 것").
nonisolated enum WorkoutTypeMapping {
    static func kind(for type: HKWorkoutActivityType) -> SegmentKind? {
        switch type {
        case .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining:
            .strength
        case .running, .walking, .cycling, .elliptical, .rowing,
             .stairClimbing, .stepTraining, .highIntensityIntervalTraining:
            .cardio
        default:
            nil
        }
    }
}
