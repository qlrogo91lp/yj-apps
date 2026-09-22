import Foundation
@testable import HaruchiFit_Watch_App
import Testing

/// **이미 가진 기록은 건드리지 않는다** — 잔디 스펙 6절의 불변조건이고, 깨지면 과거 잔디
/// 농도가 소급해서 바뀐다. 워치 기록의 시간은 정지를 뺀 앱의 값이라(PR #26)
/// `HKWorkout.duration` 과 다르기 때문이다.
struct WorkoutImportPlannerTests {
    @Test("이미 가진 UUID 는 삽입하지 않는다")
    func existingUUIDIsSkipped() {
        let mine = UUID()
        let inserts = WorkoutImportPlanner.inserts(from: [ImportFixture.workout(uuid: mine),
                                                          ImportFixture.workout()],
                                                   existing: [mine])

        #expect(inserts.count == 1)
        #expect(inserts.contains { $0.uuid == mine } == false)
    }

    @Test("같은 배치에 같은 UUID 가 두 번 오면 한 번만 넣는다")
    func duplicatesWithinBatchCollapse() {
        let uuid = UUID()
        let inserts = WorkoutImportPlanner.inserts(from: [ImportFixture.workout(uuid: uuid),
                                                          ImportFixture.workout(uuid: uuid)],
                                                   existing: [])

        #expect(inserts.count == 1)
    }

    @Test("들어온 순서를 지킨다")
    func preservesOrder() {
        let first = ImportFixture.workout()
        let second = ImportFixture.workout()
        let inserts = WorkoutImportPlanner.inserts(from: [first, second], existing: [])

        #expect(inserts.map(\.uuid) == [first.uuid, second.uuid])
    }

    @Test("가져올 것이 없으면 빈 배열이다")
    func emptyResult() {
        #expect(WorkoutImportPlanner.inserts(from: [], existing: []).isEmpty)
    }
}
