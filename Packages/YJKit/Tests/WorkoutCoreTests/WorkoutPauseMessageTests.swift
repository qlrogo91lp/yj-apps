import Foundation
import Testing
@testable import WorkoutCore

struct WorkoutPauseMessageTests {
    @Test func roundTripsThroughDictionary() {
        let id = UUID()
        let dict = WorkoutPauseMessage(sessionId: id, shouldPause: true).toDictionary()
        let restored = WorkoutPauseMessage(from: dict)
        #expect(restored?.sessionId == id)
        #expect(restored?.shouldPause == true)
    }

    @Test func roundTripsResumeCommand() {
        let id = UUID()
        let dict = WorkoutPauseMessage(sessionId: id, shouldPause: false).toDictionary()
        #expect(WorkoutPauseMessage(from: dict)?.shouldPause == false)
    }

    @Test func messageTypeIsWorkoutPause() {
        #expect(WorkoutPauseMessage.messageType == "workoutPause")
    }

    @Test func missingSessionIdFailsInit() {
        #expect(WorkoutPauseMessage(from: ["shouldPause": true]) == nil)
    }

    @Test func missingShouldPauseFailsInit() {
        #expect(WorkoutPauseMessage(from: ["sessionId": UUID().uuidString]) == nil)
    }

    @Test func malformedSessionIdFailsInit() {
        let dict: [String: Any] = ["sessionId": "not-a-uuid", "shouldPause": true]
        #expect(WorkoutPauseMessage(from: dict) == nil)
    }
}
