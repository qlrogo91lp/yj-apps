import Foundation
@testable import HaruchiFit_Watch_App
import SwiftData
import Testing

@MainActor
struct RecordDeletionTests {
    @Test("기록을 지우면 구간도 함께 사라진다")
    func deletingRecordCascadesToSegments() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 6), totalSeconds: 3600,
                                         segments: [(.strength, 0, 1800), (.cardio, 1800, 1800)])
        let keeper = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 5), totalSeconds: 1800,
                                         segments: [(.strength, 0, 1800)])
        try context.save()

        #expect(context.deleteRecord(record))

        let records = try context.fetch(FetchDescriptor<WorkoutRecord>())
        let segments = try context.fetch(FetchDescriptor<Segment>())
        #expect(records == [keeper])
        #expect(segments.count == 1)
    }
}
