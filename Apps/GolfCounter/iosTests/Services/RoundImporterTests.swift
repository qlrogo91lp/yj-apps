import Foundation
@testable import GolfCounter
import PersistenceCore
import SwiftData
import Testing

@MainActor
struct RoundImporterTests {
    private func makeContext() -> ModelContext {
        let container = PersistenceContainerFactory.make(for: [GolfRound.self],
                                                         cloudKit: false,
                                                         inMemory: true)
        return ModelContext(container)
    }

    private func makeMessage(id: UUID = UUID(), courseName: String? = nil) -> RoundCompletedMessage {
        RoundCompletedMessage(id: id,
                              startedAt: Date(timeIntervalSince1970: 1000),
                              endedAt: Date(timeIntervalSince1970: 5000),
                              courseName: courseName,
                              holeScores: [4, 5, 3],
                              holePars: [4, 4, 3],
                              puttCounts: [2, 2, 1],
                              metrics: RoundMetrics(calories: 320,
                                                    avgHeartRate: 108,
                                                    distanceMeters: 6400,
                                                    steps: 9000))
    }

    private func storedRounds(in context: ModelContext) throws -> [GolfRound] {
        try context.fetch(FetchDescriptor<GolfRound>())
    }

    @Test func 새메시지_전필드가_그대로저장된다() throws {
        let context = makeContext()
        let importer = RoundImporter(context: context)
        let id = UUID()

        let didSave = importer.save(makeMessage(id: id, courseName: "레이크사이드"))

        #expect(didSave == true)
        let rounds = try storedRounds(in: context)
        #expect(rounds.count == 1)
        let round = try #require(rounds.first)
        #expect(round.id == id)
        #expect(round.startedAt == Date(timeIntervalSince1970: 1000))
        #expect(round.endedAt == Date(timeIntervalSince1970: 5000))
        #expect(round.courseName == "레이크사이드")
        #expect(round.holeScores == [4, 5, 3])
        #expect(round.holePars == [4, 4, 3])
        #expect(round.puttCounts == [2, 2, 1])
        #expect(round.calories == 320)
        #expect(round.avgHeartRate == 108)
        #expect(round.distanceMeters == 6400)
        #expect(round.steps == 9000)
    }

    @Test func 같은id_재수신되면_저장하지않는다() throws {
        let context = makeContext()
        let importer = RoundImporter(context: context)
        let id = UUID()

        importer.save(makeMessage(id: id))
        let didSaveAgain = importer.save(makeMessage(id: id))

        #expect(didSaveAgain == false)
        #expect(try storedRounds(in: context).count == 1)
    }

    @Test func 다른id_수신되면_추가로저장된다() throws {
        let context = makeContext()
        let importer = RoundImporter(context: context)

        importer.save(makeMessage(id: UUID()))
        importer.save(makeMessage(id: UUID()))

        #expect(try storedRounds(in: context).count == 2)
    }

    @Test func 골프장명이없으면_nil로저장된다() throws {
        let context = makeContext()
        let importer = RoundImporter(context: context)

        importer.save(makeMessage(courseName: nil))

        let round = try #require(try storedRounds(in: context).first)
        #expect(round.courseName == nil)
    }
}
