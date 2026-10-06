import Foundation
@testable import HaruchiFit_Watch_App
import SwiftData
import Testing

/// 부위 태그와 메모 (제품 스펙 04 · D1 · D6). 둘 다 SwiftData 가 원본이라
/// HealthKit 에서 되살릴 수 없다 — 잃으면 끝이다.
@MainActor
struct WorkoutRecordAnnotationTests {
    private func makeRecord(in context: ModelContext) -> WorkoutRecord {
        GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 6), totalSeconds: 600)
    }

    @Test("부위는 탭할 때마다 켜고 끈다")
    func toggleFlipsPart() throws {
        let context = try GrassFixture.makeContext()
        let record = makeRecord(in: context)

        record.toggle(.chest)
        record.toggle(.arms)
        #expect(record.bodyParts == [.chest, .arms])

        record.toggle(.chest)
        #expect(record.bodyParts == [.arms])
    }

    @Test("부위는 탭한 순서가 아니라 고정 순서로 읽힌다")
    func partsReadInCanonicalOrder() throws {
        let context = try GrassFixture.makeContext()
        let record = makeRecord(in: context)

        record.toggle(.core)
        record.toggle(.chest)
        record.toggle(.legs)

        #expect(record.bodyParts == [.chest, .legs, .core])
    }

    @Test("모르는 값은 버리고 읽는다")
    func unknownRawValuesAreIgnored() throws {
        let context = try GrassFixture.makeContext()
        let record = makeRecord(in: context)

        record.bodyPartsRaw = ["back", "neck"]

        #expect(record.bodyParts == [.back])
    }

    @Test("메모는 앞뒤 공백을 자르고, 비면 nil 로 둔다")
    func memoIsTrimmedAndEmptyBecomesNil() throws {
        let context = try GrassFixture.makeContext()
        let record = makeRecord(in: context)

        record.setMemo("  벤치프레스 5×5, 딥스 \n")
        #expect(record.memo == "벤치프레스 5×5, 딥스")

        record.setMemo("   \n ")
        #expect(record.memo == nil)
    }

    @Test("워치 재전송은 열린 편집 대상을 교체하지 않고 운동 데이터만 갱신한다")
    func retransmissionUpdatesRecordInPlace() throws {
        let context = try GrassFixture.makeContext()
        let uuid = UUID()
        let record = WorkoutRecord(healthKitUUID: uuid,
                                   startedAt: GrassFixture.date(2026, 10, 6),
                                   totalSeconds: 600)
        record.segments = [Segment(kind: .strength, startOffset: 0, durationSeconds: 600)]
        record.toggle(.back)
        record.setMemo("데드리프트")
        context.insert(record)
        try context.save()
        let originalID = record.persistentModelID

        let message = WorkoutRecordMessage(
            healthKitUUID: uuid,
            startedAt: GrassFixture.date(2026, 10, 6, 7),
            endedAt: GrassFixture.date(2026, 10, 6, 7, 20),
            totalSeconds: 1200,
            activeCalories: 180,
            totalCalories: 240,
            averageHeartRate: 132,
            segments: [
                .init(kind: .strength, startOffset: 0, durationSeconds: 900),
                .init(kind: .cardio, startOffset: 900, durationSeconds: 300),
            ]
        )

        record.updateWorkoutData(from: message, in: context)
        try context.save()

        let stored = try #require(try context.fetch(FetchDescriptor<WorkoutRecord>()).first)
        #expect(stored === record)
        #expect(stored.persistentModelID == originalID)
        #expect(stored.totalSeconds == 1200)
        #expect(stored.bodyParts == [.back])
        #expect(stored.memo == "데드리프트")
        #expect(stored.orderedSegments.map(\.kind) == [.strength, .cardio])
        #expect(try context.fetchCount(FetchDescriptor<Segment>()) == 2)
    }
}
