import Foundation
@testable import TennisCounter
import Testing

@MainActor
struct SessionRecordSavingTests {
    @Test func buildsRecordFromMessage() throws {
        let viewModel = WorkoutSessionViewModel()
        let sessionId = UUID()
        let started = Date(timeIntervalSince1970: 1_700_000_000)
        let message = WorkoutEndMessage(
            sessionId: sessionId,
            startedAt: started,
            endedAt: started.addingTimeInterval(9351),
            elapsedSeconds: 9351,
            activeCalories: 1343,
            totalCalories: 1584,
            averageHeartRate: 136
        )

        let record = try #require(viewModel.saveSessionRecord(from: message))
        #expect(record.workoutSessionId == sessionId)
        #expect(record.elapsedSeconds == 9351)
        #expect(record.averageHeartRate == 136)
        #expect(record.startedAt == started)
    }

    /// 구버전 워치가 보낸 메시지는 최종값이 없다 — 레코드를 만들지 않는다.
    @Test func skipsWhenNoFinalValues() {
        let viewModel = WorkoutSessionViewModel()
        let message = WorkoutEndMessage(sessionId: UUID())
        #expect(viewModel.saveSessionRecord(from: message) == nil)
    }
}
