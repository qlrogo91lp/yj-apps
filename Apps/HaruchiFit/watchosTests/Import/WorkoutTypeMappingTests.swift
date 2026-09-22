@testable import HaruchiFit_Watch_App
import HealthKit
import Testing

/// 매핑 표는 **D-M5 를 지키는 유일한 지점**이다. 집계기는 필터를 갖지 않는다 (잔디 스펙 4.5).
struct WorkoutTypeMappingTests {
    @Test("근력 3종", arguments: [
        HKWorkoutActivityType.traditionalStrengthTraining,
        .functionalStrengthTraining,
        .coreTraining,
    ])
    func strengthTypes(_ type: HKWorkoutActivityType) {
        #expect(WorkoutTypeMapping.kind(for: type) == .strength)
    }

    @Test("유산소 8종", arguments: [
        HKWorkoutActivityType.running,
        .walking,
        .cycling,
        .elliptical,
        .rowing,
        .stairClimbing,
        .stepTraining,
        .highIntensityIntervalTraining,
    ])
    func cardioTypes(_ type: HKWorkoutActivityType) {
        #expect(WorkoutTypeMapping.kind(for: type) == .cardio)
    }

    /// **.other · .mixedCardio · .crossTraining 을 뺀 것이 이 표의 핵심 판단이다** (스펙 2절).
    /// 사용자가 그 안에 무엇을 넣었는지 앱이 알 수 없고, 오분류가 Phase 4 비율 차트의 분모로 들어간다.
    @Test("표에 없는 타입은 import 하지 않는다", arguments: [
        HKWorkoutActivityType.other,
        .mixedCardio,
        .crossTraining,
        .yoga,
        .pilates,
        .swimming,
        .hiking,
        .tennis,
        .golf,
    ])
    func unmappedTypesAreNil(_ type: HKWorkoutActivityType) {
        #expect(WorkoutTypeMapping.kind(for: type) == nil)
    }
}
