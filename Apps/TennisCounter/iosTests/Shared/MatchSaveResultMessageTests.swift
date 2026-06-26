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
}
