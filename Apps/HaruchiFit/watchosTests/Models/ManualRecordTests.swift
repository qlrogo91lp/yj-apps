import Foundation
@testable import HaruchiFit_Watch_App
import SwiftData
import Testing

@MainActor
struct ManualRecordTests {
    private let now = GrassFixture.date(2026, 10, 8, 12)

    @Test("필수값만으로 HealthKit 연결 없는 단일 구간 기록을 만든다")
    func createsSingleSegment() throws {
        let start = GrassFixture.date(2026, 10, 8, 10)
        let draft = ManualRecordDraft(startedAt: start, durationMinutes: 90, kind: .cardio)
        let record = try WorkoutRecord.makeManual(from: draft, now: now)

        #expect(record.source == .manual)
        #expect(record.healthKitUUID == nil)
        #expect(record.startedAt == start)
        #expect(record.endedAt == GrassFixture.date(2026, 10, 8, 11, 30))
        #expect(record.totalSeconds == 5400)
        #expect(record.totalCalories == nil)
        #expect(record.averageHeartRate == nil)
        #expect(record.orderedSegments.count == 1)
        #expect(record.orderedSegments.first?.kind == .cardio)
        #expect(record.orderedSegments.first?.durationSeconds == 5400)
    }

    @Test("0분과 미래에 끝나는 기록을 거부한다")
    func rejectsInvalidTime() {
        let start = GrassFixture.date(2026, 10, 8, 11, 30)
        #expect(throws: ManualRecordDraft.ValidationError.self) {
            try ManualRecordDraft(startedAt: start, durationMinutes: 0, kind: .strength).validate(now: now)
        }
        #expect(throws: ManualRecordDraft.ValidationError.self) {
            try ManualRecordDraft(startedAt: start, durationMinutes: 60, kind: .strength).validate(now: now)
        }
    }

    @Test("편집은 같은 모델에 날짜·구간·부위·메모를 갱신한다")
    func editsInPlace() throws {
        let context = try GrassFixture.makeContext()
        let original = try WorkoutRecord.makeManual(
            from: ManualRecordDraft(startedAt: GrassFixture.date(2026, 10, 7, 9), durationMinutes: 30, kind: .strength),
            now: now
        )
        context.insert(original)
        try context.save()
        let id = original.persistentModelID

        let revised = ManualRecordDraft(startedAt: GrassFixture.date(2026, 10, 8, 10), durationMinutes: 60,
                                        kind: .cardio, bodyParts: [.chest, .arms], memo: "  달리기  ")
        try original.applyManual(revised, now: now, in: context)
        try context.save()

        #expect(original.persistentModelID == id)
        #expect(original.startedAt == GrassFixture.date(2026, 10, 8, 10))
        #expect(original.totalSeconds == 3600)
        #expect(original.orderedSegments.count == 1)
        #expect(original.orderedSegments.first?.kind == .cardio)
        #expect(original.bodyParts == [.chest, .arms])
        #expect(original.memo == "달리기")
        #expect(try context.fetch(FetchDescriptor<WorkoutRecord>()).count == 1)
    }

    @Test("워치 기록은 수동 편집으로 바꿀 수 없다")
    func protectsImportedMetrics() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 7), totalSeconds: 1800)
        let draft = ManualRecordDraft(startedAt: GrassFixture.date(2026, 10, 8, 10), durationMinutes: 60, kind: .cardio)
        #expect(throws: ManualRecordDraft.ValidationError.self) {
            try record.applyManual(draft, now: now, in: context)
        }
        #expect(record.totalSeconds == 1800)
        #expect(record.source == .watch)
    }

    @Test("수동 기록의 시간과 유형을 잔디 집계에 반영한다")
    func contributesToGrass() throws {
        let context = try GrassFixture.makeContext()
        let record = try WorkoutRecord.makeManual(
            from: ManualRecordDraft(startedAt: GrassFixture.date(2026, 10, 8, 9), durationMinutes: 90, kind: .strength),
            now: now
        )
        context.insert(record)
        let day = try #require(GrassAggregator.fold(context.fetch(FetchDescriptor<WorkoutRecord>()),
                                                    calendar: GrassFixture.seoul).first)
        #expect(day.totalSeconds == 5400)
        #expect(day.strengthSeconds == 5400)
        #expect(GrassIntensity.byTime.level(for: day) == .peak)
    }

    @Test("날짜와 유형을 바꾸면 목록·잔디·통계가 새 값으로 재계산된다")
    func editedRecordFeedsExistingBuilders() throws {
        let context = try GrassFixture.makeContext()
        let originalDay = GrassFixture.date(2026, 10, 7, 9)
        let newDay = GrassFixture.date(2026, 10, 8, 9)
        let record = try WorkoutRecord.makeManual(
            from: ManualRecordDraft(startedAt: originalDay, durationMinutes: 30, kind: .strength), now: now
        )
        context.insert(record)
        try context.save()
        try record.applyManual(ManualRecordDraft(startedAt: newDay, durationMinutes: 90,
                                                 kind: .cardio, bodyParts: [.legs]), now: now, in: context)
        try context.save()

        let stored = try context.fetch(FetchDescriptor<WorkoutRecord>())
        let list = RecordListBuilder.sections(from: stored, now: now, calendar: GrassFixture.seoul)
        let grass = GrassAggregator.fold(stored, calendar: GrassFixture.seoul)
        let stats = StatisticsBuilder.dashboard(from: stored.map(StatisticsRecordInput.init(record:)),
                                                aggregates: grass, selectedYear: 2026,
                                                now: now, calendar: GrassFixture.seoul)

        #expect(list.flatMap(\.rows).first?.chips.first?.text == "유산소 90분")
        #expect(grass.count == 1)
        #expect(grass.first?.day == GrassFixture.seoul.startOfDay(for: newDay))
        #expect(stats.countText == "1회")
        #expect(stats.composition?.cardioSeconds == 5400)
        #expect(stats.bodyParts.first?.part == .legs)
    }
}
