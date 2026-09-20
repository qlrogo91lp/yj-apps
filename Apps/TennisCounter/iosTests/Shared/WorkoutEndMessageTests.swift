import Foundation
import Testing
@testable import TennisCounter

struct WorkoutEndMessageTests {
    @Test func roundTripWithFinalValues() throws {
        let sessionId = UUID()
        let started = Date(timeIntervalSince1970: 1_700_000_000)
        let ended = started.addingTimeInterval(9351)
        let original = WorkoutEndMessage(
            sessionId: sessionId,
            startedAt: started,
            endedAt: ended,
            elapsedSeconds: 9351,
            activeCalories: 1343,
            totalCalories: 1584,
            averageHeartRate: 136,
            healthKitUUID: nil
        )

        let decoded = try #require(WorkoutEndMessage(from: original.toDictionary()))
        #expect(decoded.sessionId == sessionId)
        #expect(decoded.elapsedSeconds == 9351)
        #expect(decoded.activeCalories == 1343)
        #expect(decoded.totalCalories == 1584)
        #expect(decoded.averageHeartRate == 136)
        #expect(decoded.endedAt?.timeIntervalSince1970 == ended.timeIntervalSince1970)
    }

    /// 구버전 워치가 보내는 sessionId 만 있는 메시지도 계속 읽혀야 한다.
    @Test func decodesLegacyMessageWithoutFinalValues() throws {
        let sessionId = UUID()
        let legacy: [String: Any] = ["sessionId": sessionId.uuidString]

        let decoded = try #require(WorkoutEndMessage(from: legacy))
        #expect(decoded.sessionId == sessionId)
        #expect(decoded.elapsedSeconds == nil)
        #expect(decoded.averageHeartRate == nil)
    }
}
