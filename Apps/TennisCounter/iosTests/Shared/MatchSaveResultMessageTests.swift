import Foundation
@testable import TennisCounter
import Testing

struct MatchSaveResultMessageTests {
    @Test func dictionaryUsesMatchSaveResultType() {
        let msg = MatchSaveResultMessage(sessionId: UUID(), success: true)
        #expect(msg.toDictionary()["type"] as? String == "matchSaveResult")
    }

    @Test func dictionaryRoundTripsOnSuccess() {
        let original = MatchSaveResultMessage(sessionId: UUID(), success: true)
        guard let decoded = MatchSaveResultMessage(from: original.toDictionary()) else {
            Issue.record("matchSaveResult 페이로드가 파싱되지 않음")
            return
        }
        #expect(decoded.sessionId == original.sessionId)
        #expect(decoded.success == true)
    }

    @Test func dictionaryRoundTripsOnFailure() {
        let original = MatchSaveResultMessage(sessionId: UUID(), success: false)
        let decoded = MatchSaveResultMessage(from: original.toDictionary())
        #expect(decoded?.success == false)
    }

    @Test func parsingFailsForWrongType() {
        #expect(MatchSaveResultMessage(from: ["type": "matchSave"]) == nil)
    }

    // MARK: - matchId (워치 보관함이 ACK 받은 경기 하나만 지우는 키)

    @Test func roundTripCarriesMatchId() {
        let sid = UUID(), mid = UUID()
        let decoded = MatchSaveResultMessage(from: MatchSaveResultMessage(sessionId: sid, success: true, matchId: mid).toDictionary())
        #expect(decoded?.matchId == mid)
        #expect(decoded?.sessionId == sid)
    }

    /// 구버전 폰(1.2.0)의 ACK 에는 matchId 가 없다 — 그래도 읽혀야 한다.
    @Test func legacyPayloadWithoutMatchIdDecodesWithNil() {
        let sid = UUID()
        let decoded = MatchSaveResultMessage(from: ["type": "matchSaveResult", "sessionId": sid.uuidString, "success": true])
        #expect(decoded != nil)
        #expect(decoded?.matchId == nil)
    }

    @Test func nilMatchIdIsNotWrittenToDictionary() {
        let dict = MatchSaveResultMessage(sessionId: UUID(), success: false).toDictionary()
        #expect(dict["matchId"] == nil)
    }
}
