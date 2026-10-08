import Foundation
@testable import HaruchiFit_Watch_App
import SwiftData
import Testing

@MainActor
struct RecordDisplayInputTests {
    @Test("같은 영속 기록의 날짜와 시간 변경은 표시 입력 변경으로 감지한다")
    func noticesInPlaceDisplayChanges() throws {
        let context = try GrassFixture.makeContext()
        let record = GrassFixture.record(in: context, startedAt: GrassFixture.date(2026, 10, 8), totalSeconds: 1800)
        let before = RecordDisplayInput(record: record)

        record.startedAt = GrassFixture.date(2026, 9, 30)
        record.totalSeconds = 5400
        let after = RecordDisplayInput(record: record)

        #expect(before != after)
    }
}
