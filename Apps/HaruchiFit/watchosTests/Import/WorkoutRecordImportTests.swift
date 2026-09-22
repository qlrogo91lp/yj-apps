import Foundation
@testable import HaruchiFit_Watch_App
import SwiftData
import Testing

/// import 기록은 **전환이 0 회인 세션**이다. 세그먼트를 안 만들면 잔디 농도는 채워지는데
/// 비율 차트에서만 빠지는 절름발이 레코드가 되고, 집계기가 분기를 갖게 된다 (스펙 5절).
@MainActor
struct WorkoutRecordImportTests {
    @Test("매핑된 kind 로 전체 길이 세그먼트 1 개를 만든다")
    func makesSingleFullLengthSegment() {
        let record = WorkoutRecord.make(from: ImportFixture.workout(kind: .cardio, totalSeconds: 1800))

        #expect(record.orderedSegments.count == 1)
        #expect(record.orderedSegments.first?.kind == .cardio)
        #expect(record.orderedSegments.first?.startOffset == 0)
        #expect(record.orderedSegments.first?.durationSeconds == 1800)
    }

    /// 다른 앱 워크아웃에는 basal 샘플이 붙어 있지 않다. active 를 그대로 쓰는 편이
    /// nil 보다 낫고 카드·요약이 빈칸을 피한다 (스펙 5절).
    @Test("totalCalories 는 activeCalories 와 같다")
    func totalCaloriesMirrorActive() {
        let record = WorkoutRecord.make(from: ImportFixture.workout(activeCalories: 240))

        #expect(record.activeCalories == 240)
        #expect(record.totalCalories == 240)
    }

    @Test("출처는 healthKitImport 이고 UUID 가 보존된다")
    func sourceAndKey() {
        let uuid = UUID()
        let record = WorkoutRecord.make(from: ImportFixture.workout(uuid: uuid))

        #expect(record.source == .healthKitImport)
        #expect(record.healthKitUUID == uuid)
    }

    /// 집계까지 한 번 이어서 본다 — 세그먼트 1 개가 실제로 cardioSeconds 로 접히는지.
    @Test("import 레코드가 잔디 집계에서 유산소 시간으로 접힌다")
    func foldsIntoCardioSeconds() throws {
        let context = try GrassFixture.makeContext()
        context.insert(WorkoutRecord.make(from: ImportFixture.workout(kind: .cardio, totalSeconds: 1800)))

        let days = try GrassAggregator.fold(context.fetch(FetchDescriptor<WorkoutRecord>()),
                                            calendar: GrassFixture.seoul)

        #expect(days.first?.cardioSeconds == 1800)
        #expect(days.first?.strengthSeconds == 0)
    }
}
