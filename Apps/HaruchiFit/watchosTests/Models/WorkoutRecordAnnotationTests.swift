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

    @Test("워치가 같은 기록을 다시 보내도 부위와 메모를 이어받는다")
    func adoptAnnotationsSurvivesReplacement() throws {
        let context = try GrassFixture.makeContext()
        let old = makeRecord(in: context)
        old.toggle(.back)
        old.setMemo("데드리프트")
        try context.save()

        // iOSApp.save(_:) 의 upsert(replacing:) 와 같은 순서 — 지우고 새로 넣는다
        let fresh = WorkoutRecord(startedAt: old.startedAt, totalSeconds: 700)
        fresh.adoptAnnotations(from: old)
        context.delete(old)
        context.insert(fresh)
        try context.save()

        let stored = try context.fetch(FetchDescriptor<WorkoutRecord>())
        #expect(stored.count == 1)
        #expect(stored.first?.totalSeconds == 700)
        #expect(stored.first?.bodyParts == [.back])
        #expect(stored.first?.memo == "데드리프트")
    }
}
