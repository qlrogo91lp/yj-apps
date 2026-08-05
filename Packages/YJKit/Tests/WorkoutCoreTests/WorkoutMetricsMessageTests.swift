import Testing
@testable import WorkoutCore

struct WorkoutMetricsMessageTests {
    @Test func roundTripsThroughDictionary() {
        let original = WorkoutMetrics(elapsedSeconds: 1523,
                                      activeCalories: 245,
                                      totalCalories: 310,
                                      heartRate: 142)
        let dict = WorkoutMetricsMessage(metrics: original).toDictionary()
        let restored = WorkoutMetricsMessage(from: dict)
        #expect(restored?.metrics == original)
    }

    @Test func missingElapsedFailsInit() {
        #expect(WorkoutMetricsMessage(from: ["calories": 100.0]) == nil)
    }

    /// 구버전 워치는 totalCalories 키를 안 보낸다 — 활동 칼로리로 폴백해야 한다.
    @Test func legacyPayloadWithoutTotalCaloriesFallsBackToActive() {
        let dict: [String: Any] = ["elapsed": 600.0, "calories": 120.0, "heartRate": 130.0]
        let message = WorkoutMetricsMessage(from: dict)
        #expect(message?.metrics.totalCalories == 120)
        #expect(message?.metrics.activeCalories == 120)
    }

    @Test func messageTypeIsMetrics() {
        #expect(WorkoutMetricsMessage.messageType == "metrics")
    }

    @Test func wireKeysMatchLegacyFormat() {
        let dict = WorkoutMetricsMessage(
            metrics: WorkoutMetrics(elapsedSeconds: 10, activeCalories: 20, totalCalories: 30, heartRate: 40)
        ).toDictionary()
        #expect(dict["elapsed"] as? Double == 10)
        #expect(dict["calories"] as? Double == 20)
        #expect(dict["totalCalories"] as? Double == 30)
        #expect(dict["heartRate"] as? Double == 40)
    }
}
