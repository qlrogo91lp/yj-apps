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

    @Test func sessionStartMessageRoundTripsMatchId() {
        let matchId = UUID()
        let original = SessionStartMessage(
            sessionId: UUID(),
            matchId: matchId,
            options: MatchOptions(mode: .bestOfThree, noAdRule: true, noTieRule: false),
            workoutStartDate: Date(timeIntervalSince1970: 1_000_000)
        )
        guard let decoded = SessionStartMessage(from: original.toDictionary()) else {
            Issue.record("SessionStartMessage 파싱 실패")
            return
        }
        #expect(decoded.matchId == matchId)
        #expect(decoded.sessionId == original.sessionId)
    }

    /// 구버전 워치는 matchId 키를 보내지 않는다. 이때 파싱이 실패하면 세션 미러링이
    /// 통째로 깨지므로, nil로 읽히되 메시지 자체는 살아 있어야 한다.
    @Test func sessionStartMessageFromLegacyPayloadHasNilMatchId() {
        let legacy: [String: Any] = [
            "type": "sessionStart",
            "sessionId": UUID().uuidString,
            "mode": "one_set",
            "noAdRule": true,
            "noTieRule": false,
            "gameThreshold": 6,
            "workoutStartDate": 1_000_000.0,
        ]
        guard let decoded = SessionStartMessage(from: legacy) else {
            Issue.record("구버전 페이로드가 거부됨 — 세션 미러링이 깨진다")
            return
        }
        #expect(decoded.matchId == nil)
    }
}
