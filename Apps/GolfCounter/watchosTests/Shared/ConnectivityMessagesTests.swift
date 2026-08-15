import Foundation
@testable import GolfCounter_Watch_App
import Testing

struct ConnectivityMessagesTests {
    private func sample(courseName: String?) -> RoundCompletedMessage {
        RoundCompletedMessage(id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
                              startedAt: Date(timeIntervalSince1970: 1000),
                              endedAt: Date(timeIntervalSince1970: 5000),
                              courseName: courseName,
                              holeScores: [4, 5, 3],
                              holePars: [4, 5, 3],
                              puttCounts: [2, 2, 1],
                              metrics: RoundMetrics(calories: 412,
                                                    avgHeartRate: 118,
                                                    distanceMeters: 6200,
                                                    steps: 9100))
    }

    @Test func 딕셔너리_왕복에서_전_필드가_유지된다() throws {
        let original = sample(courseName: "테스트CC")

        let restored = try #require(RoundCompletedMessage(from: original.toDictionary()))

        #expect(restored.id == original.id)
        #expect(restored.startedAt == original.startedAt)
        #expect(restored.endedAt == original.endedAt)
        #expect(restored.courseName == "테스트CC")
        #expect(restored.holeScores == [4, 5, 3])
        #expect(restored.holePars == [4, 5, 3])
        #expect(restored.puttCounts == [2, 2, 1])
        #expect(restored.metrics == original.metrics)
    }

    @Test func 골프장명이_없으면_키_자체가_빠진다() {
        let dictionary = sample(courseName: nil).toDictionary()

        #expect(dictionary["courseName"] == nil)
    }

    @Test func 골프장명이_없어도_복원된다() throws {
        let original = sample(courseName: nil)

        let restored = try #require(RoundCompletedMessage(from: original.toDictionary()))

        #expect(restored.courseName == nil)
    }

    @Test func 필수_필드가_빠지면_복원에_실패한다() {
        var dictionary = sample(courseName: nil).toDictionary()
        dictionary.removeValue(forKey: "holeScores")

        #expect(RoundCompletedMessage(from: dictionary) == nil)
    }

    @Test func 메시지_타입은_roundCompleted다() {
        #expect(RoundCompletedMessage.messageType == "roundCompleted")
    }
}
