import Foundation
@testable import HaruchiFit_Watch_App
import SwiftData
import Testing

@MainActor
struct DuplicateCleanupTests {
    private func pair(_ context: ModelContext, source: WorkoutSource = .watch) throws -> (WorkoutRecord, WorkoutRecord) {
        let id = UUID()
        let keeper = GrassFixture.record(in: context, startedAt: Date(), totalSeconds: 20,
                                         segments: [(.strength, 0, 10), (.cardio, 10, 10)])
        keeper.healthKitUUID = id
        keeper.source = source
        let other = GrassFixture.record(in: context, startedAt: Date(), totalSeconds: 20,
                                        segments: [(.strength, 0, 20)])
        other.healthKitUUID = id
        other.source = .healthKitImport
        try context.save()
        return (keeper, other)
    }

    @Test func removeDuplicatesKeepsWatchRecordOverHealthKitImport() throws {
        let context = try GrassFixture.makeContext()
        _ = try pair(context)
        #expect(try context.removeDuplicateWorkouts() == 1)
        let records = try context.fetch(FetchDescriptor<WorkoutRecord>())
        #expect(records.count == 1)
        #expect(records.first?.source == .watch)
        #expect(records.first?.orderedSegments.map(\.kind) == [.strength, .cardio])
    }

    @Test func removeDuplicatesPrefersAnnotatedRecordWhenSourcesMatch() throws {
        let context = try GrassFixture.makeContext()
        let (first, other) = try pair(context, source: .healthKitImport)
        first.memo = "하체"
        first.bodyPartsRaw = ["legs"]
        other.segments?.append(Segment(kind: .cardio, startOffset: 10, durationSeconds: 10))
        #expect(try context.removeDuplicateWorkouts() == 1)
        #expect(try context.fetch(FetchDescriptor<WorkoutRecord>()).first?.memo == "하체")
    }

    @Test func removeDuplicatesCopiesMemoAndBodyPartsFromRemovedRecord() throws {
        let context = try GrassFixture.makeContext()
        let (_, other) = try pair(context)
        other.memo = "복원 전 메모"
        other.bodyPartsRaw = ["chest"]
        #expect(try context.removeDuplicateWorkouts() == 1)
        let record = try #require(context.fetch(FetchDescriptor<WorkoutRecord>()).first)
        #expect(record.source == .watch)
        #expect(record.memo == "복원 전 메모")
        #expect(record.bodyPartsRaw == ["chest"])
    }

    @Test func removeDuplicatesKeepsKeeperMemoWhenBothHaveOne() throws {
        let context = try GrassFixture.makeContext()
        let (keeper, other) = try pair(context)
        keeper.memo = "원래"
        other.memo = "임시"
        #expect(try context.removeDuplicateWorkouts() == 1)
        #expect(try context.fetch(FetchDescriptor<WorkoutRecord>()).first?.memo == "원래")
    }

    @Test func removeDuplicatesLeavesManualRecordsAlone() throws {
        let context = try GrassFixture.makeContext()
        let date = Date()
        context.insert(WorkoutRecord(startedAt: date, source: .manual))
        context.insert(WorkoutRecord(startedAt: date, source: .manual))
        #expect(try context.removeDuplicateWorkouts() == 0)
        #expect(try context.fetch(FetchDescriptor<WorkoutRecord>()).count == 2)
    }

    @Test func removeDuplicatesLeavesUniqueRecordsAlone() throws {
        let context = try GrassFixture.makeContext()
        for _ in 0 ..< 3 {
            context.insert(WorkoutRecord(healthKitUUID: UUID()))
        }
        #expect(try context.removeDuplicateWorkouts() == 0)
        #expect(try context.fetch(FetchDescriptor<WorkoutRecord>()).count == 3)
    }

    @Test func removeDuplicatesDeletesSegmentsOfRemovedRecord() throws {
        let context = try GrassFixture.makeContext()
        _ = try pair(context)
        #expect(try context.removeDuplicateWorkouts() == 1)
        #expect(try context.fetch(FetchDescriptor<Segment>()).count == 2)
    }

    @Test func removeDuplicatesTieLeavesExactlyOne() throws {
        let context = try GrassFixture.makeContext()
        let id = UUID()
        for _ in 0 ..< 2 {
            let record = GrassFixture.record(in: context, startedAt: Date(), totalSeconds: 20,
                                             segments: [(.strength, 0, 20)])
            record.healthKitUUID = id
            record.source = .healthKitImport
        }
        #expect(try context.removeDuplicateWorkouts() == 1)
        #expect(try context.fetch(FetchDescriptor<WorkoutRecord>()).count(where: { $0.healthKitUUID == id }) == 1)
    }

    @Test func removeDuplicatesSkipsGroupContainingProtectedRecord() throws {
        let context = try GrassFixture.makeContext()
        let (_, other) = try pair(context)
        #expect(try context.removeDuplicateWorkouts(protecting: [other.persistentModelID]) == 0)
        #expect(try context.fetch(FetchDescriptor<WorkoutRecord>()).count == 2)
    }
}
