import Foundation
@testable import TennisCounter
import Testing

struct ConnectivityMessagesTests {
    @Test func workoutEndMessageRoundTrips() {
        let id = UUID()
        let decoded = WorkoutEndMessage(from: WorkoutEndMessage(sessionId: id).toDictionary())
        #expect(decoded?.sessionId == id)
    }

    @Test func matchResetMessageRoundTrips() {
        let id = UUID()
        let decoded = MatchResetMessage(from: MatchResetMessage(sessionId: id).toDictionary())
        #expect(decoded?.sessionId == id)
    }

    @Test func workoutEndMessageRejectsMalformedSessionId() {
        #expect(WorkoutEndMessage(from: ["sessionId": "not-a-uuid"]) == nil)
    }

    @Test func matchSaveMessageRoundTripsThroughSaveDictionary() {
        let base = MatchEndMessage(
            sessionId: UUID(), result: "win", completedSets: [[6, 3]],
            startedAt: Date(timeIntervalSince1970: 1000), endedAt: Date(timeIntervalSince1970: 2000),
            durationSeconds: 1000, calories: 120, averageHeartRate: 130, mode: "oneSet", noAdRule: true
        )
        let decoded = MatchSaveMessage(from: MatchSaveMessage(base: base).toDictionary())
        #expect(decoded?.base.sessionId == base.sessionId)
        #expect(decoded?.base.result == "win")
        #expect(decoded?.base.completedSets == [[6, 3]])
    }

    @Test func matchSaveMessageRejectsMatchEndDictionary() {
        let base = MatchEndMessage(
            sessionId: UUID(), result: "win", completedSets: [],
            startedAt: Date(), endedAt: Date(),
            durationSeconds: 0, calories: 0, averageHeartRate: nil, mode: "oneSet", noAdRule: true
        )
        // toDictionary()는 type=matchEnd — matchSave 라우팅용 디코드는 거부해야 한다
        #expect(MatchSaveMessage(from: base.toDictionary()) == nil)
    }

    @Test func workoutMetricsConformsWithMetricsType() {
        #expect(WorkoutMetrics.messageType == "metrics")
        let decoded = WorkoutMetrics(from: WorkoutMetrics(elapsedSeconds: 10, calories: 5, heartRate: 120, steps: 0).toDictionary())
        #expect(decoded?.heartRate == 120)
    }
}
