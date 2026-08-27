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

    @Test func roundTripsIsPaused() {
        let dict = WorkoutMetricsMessage(
            metrics: WorkoutMetrics(elapsedSeconds: 10), isPaused: true
        ).toDictionary()
        #expect(dict["isPaused"] as? Bool == true)
        #expect(WorkoutMetricsMessage(from: dict)?.isPaused == true)
    }

    @Test func isPausedDefaultsToFalseOnConstruction() {
        #expect(WorkoutMetricsMessage(metrics: WorkoutMetrics()).isPaused == false)
    }

    /// 구버전 워치 페이로드에는 isPaused 키가 없다 — 진행 중으로 본다.
    @Test func legacyPayloadWithoutIsPausedDefaultsToRunning() {
        let dict: [String: Any] = ["elapsed": 600.0, "calories": 120.0]
        #expect(WorkoutMetricsMessage(from: dict)?.isPaused == false)
    }

    /// sentAt은 ConnectivityService가 스탬프한다 — 발신 시엔 nil이고 수신 dict에서만 읽힌다.
    @Test func sentAtIsNilOnConstructionAndReadOnReceive() {
        #expect(WorkoutMetricsMessage(metrics: WorkoutMetrics()).sentAt == nil)
        let dict: [String: Any] = ["elapsed": 5.0, "sentAt": 1_700_000_000.0]
        #expect(WorkoutMetricsMessage(from: dict)?.sentAt == 1_700_000_000)
    }

    @Test func toDictionaryOmitsSentAt() {
        let dict = WorkoutMetricsMessage(metrics: WorkoutMetrics()).toDictionary()
        #expect(dict["sentAt"] == nil)
    }
}
