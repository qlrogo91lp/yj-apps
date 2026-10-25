import Foundation
@testable import HaruchiFit_Watch_App
import SwiftData
import Testing

@MainActor
struct WatchRecordSaveTests {
    private let start = Date(timeIntervalSince1970: 1_760_000_000)

    private func message(uuid: UUID?,
                         offset: TimeInterval = 0,
                         segments: [WorkoutRecordMessage.SegmentPayload]? = nil,
                         activeCalories: Double = 200,
                         totalCalories: Double = 260) -> WorkoutRecordMessage
    {
        let payload = segments ?? [.init(kind: .strength, startOffset: 0, durationSeconds: 1800),
                                   .init(kind: .cardio, startOffset: 1800, durationSeconds: 1800)]
        return WorkoutRecordMessage(healthKitUUID: uuid,
                                    startedAt: start.addingTimeInterval(offset),
                                    endedAt: start.addingTimeInterval(offset + 3600),
                                    totalSeconds: 3600,
                                    activeCalories: activeCalories,
                                    totalCalories: totalCalories,
                                    averageHeartRate: 120,
                                    segments: payload)
    }

    private func records(_ context: ModelContext) throws -> [WorkoutRecord] {
        try context.fetch(FetchDescriptor<WorkoutRecord>(sortBy: [SortDescriptor(\.startedAt)]))
    }

    @Test("새 UUID 면 기록 한 건과 구간이 그대로 들어간다")
    func newRecordIsInserted() throws {
        let context = try GrassFixture.makeContext()

        try context.saveWatchRecord(message(uuid: UUID()))

        let saved = try records(context)
        #expect(saved.count == 1)
        #expect(saved[0].source == .watch)
        #expect(saved[0].orderedSegments.map(\.kind) == [.strength, .cardio])
        #expect(saved[0].orderedSegments.map(\.durationSeconds) == [1800, 1800])
    }

    @Test("같은 UUID 를 다시 보내면 부위·메모·영속 ID 를 유지한다")
    func resendKeepsAnnotations() throws {
        let context = try GrassFixture.makeContext()
        let uuid = UUID()
        try context.saveWatchRecord(message(uuid: uuid))
        let original = try #require(records(context).first)
        let id = original.persistentModelID
        original.toggle(.chest)
        original.setMemo("가슴 데이")

        try context.saveWatchRecord(message(uuid: uuid, activeCalories: 300))

        let saved = try records(context)
        #expect(saved.count == 1)
        #expect(saved[0].persistentModelID == id)
        #expect(saved[0].bodyParts == [.chest])
        #expect(saved[0].memo == "가슴 데이")
        #expect(saved[0].activeCalories == 300)
    }

    @Test("건강 앱 import 가 먼저 만든 근력 기록을 워치 기록으로 바로잡는다")
    func importedRecordIsCorrectedByWatchRecord() throws {
        let context = try GrassFixture.makeContext()
        let uuid = UUID()
        let imported = WorkoutRecord.make(from: ImportedWorkout(uuid: uuid, kind: .strength,
                                                                startedAt: start,
                                                                endedAt: start.addingTimeInterval(3600),
                                                                totalSeconds: 3600,
                                                                activeCalories: 200,
                                                                averageHeartRate: 120))
        context.insert(imported)
        try context.save()

        try context.saveWatchRecord(message(uuid: uuid, totalCalories: 260))

        let saved = try records(context)
        #expect(saved.count == 1)
        #expect(saved[0].source == .watch)
        #expect(saved[0].totalCalories == 260)
        #expect(saved[0].orderedSegments.map(\.kind) == [.strength, .cardio])
        #expect(try context.fetch(FetchDescriptor<Segment>()).count == 2)
    }

    @Test("서로 다른 UUID 를 연달아 저장하면 둘 다 남는다")
    func consecutiveMessagesAreAllSaved() throws {
        let context = try GrassFixture.makeContext()

        try context.saveWatchRecord(message(uuid: UUID()))
        try context.saveWatchRecord(message(uuid: UUID(), offset: 7200))

        #expect(try records(context).count == 2)
    }

    @Test("UUID 가 없으면 중복 검사 없이 추가한다")
    func recordWithoutUUIDIsInserted() throws {
        let context = try GrassFixture.makeContext()

        try context.saveWatchRecord(message(uuid: nil))
        try context.saveWatchRecord(message(uuid: nil))

        #expect(try records(context).count == 2)
    }
}
