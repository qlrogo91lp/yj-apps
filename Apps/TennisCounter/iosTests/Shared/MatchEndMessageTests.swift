import Foundation
@testable import TennisCounter
import Testing

struct MatchEndMessageTests {
    private func sample() -> MatchEndMessage {
        MatchEndMessage(
            sessionId: UUID(),
            result: "win",
            completedSets: [[6, 4], [3, 6], [7, 5]],
            startedAt: Date(timeIntervalSince1970: 1_000_000),
            endedAt: Date(timeIntervalSince1970: 1_008_777),
            durationSeconds: 8777,
            calories: 1179,
            averageHeartRate: 136,
            mode: "bestOfThree",
            noAdRule: true
        )
    }

    /// 경기 종료(표시용)와 저장 요청은 서로 다른 메시지 타입이어야 한다.
    /// → iOS가 matchEnd는 결과 표시만, matchSave를 받을 때만 persist 한다.
    @Test func endDictionaryUsesMatchEndType() {
        #expect(sample().toDictionary()["type"] as? String == "matchEnd")
    }

    @Test func saveDictionaryUsesMatchSaveType() {
        #expect(sample().toSaveDictionary()["type"] as? String == "matchSave")
    }

    @Test func saveDictionaryRoundTrips() {
        let original = sample()
        guard let decoded = MatchEndMessage(from: original.toSaveDictionary()) else {
            Issue.record("save 페이로드가 MatchEndMessage로 파싱되지 않음")
            return
        }
        #expect(decoded.sessionId == original.sessionId)
        #expect(decoded.result == original.result)
        #expect(decoded.completedSets == original.completedSets)
        #expect(decoded.durationSeconds == original.durationSeconds)
        #expect(decoded.calories == original.calories)
        #expect(decoded.averageHeartRate == original.averageHeartRate)
        #expect(decoded.mode == original.mode)
        #expect(decoded.noAdRule == original.noAdRule)
    }

    @Test func endDictionaryAlsoParses() {
        #expect(MatchEndMessage(from: sample().toDictionary()) != nil)
    }

    @Test func matchEndMessageRoundTripsTotalCalories() {
        let msg = MatchEndMessage(
            sessionId: UUID(), result: "win", completedSets: [[6, 4]],
            startedAt: Date(timeIntervalSince1970: 1000),
            endedAt: Date(timeIntervalSince1970: 4600),
            durationSeconds: 3600, calories: 320, averageHeartRate: 135,
            mode: "one_set", noAdRule: true, totalCalories: 415
        )
        let restored = MatchEndMessage(from: msg.toDictionary())
        #expect(restored?.totalCalories == 415)
        #expect(restored?.calories == 320)
    }

    /// 구버전 워치 페이로드에는 totalCalories 키가 없다 — nil이어야 저장 시
    /// "값 없음"과 "0 kcal"을 구분할 수 있다.
    @Test func matchEndMessageTotalCaloriesIsNilWhenKeyMissing() {
        let dict: [String: Any] = [
            "type": "matchEnd",
            "sessionId": UUID().uuidString,
            "result": "win",
            "sets": [[6, 4]],
            "startedAt": 1000.0,
            "endedAt": 4600.0,
            "durationSeconds": 3600,
            "calories": 320.0,
            "mode": "one_set",
            "noAdRule": true,
        ]
        let restored = MatchEndMessage(from: dict)
        #expect(restored?.totalCalories == nil)
        #expect(restored?.calories == 320)
    }
}
