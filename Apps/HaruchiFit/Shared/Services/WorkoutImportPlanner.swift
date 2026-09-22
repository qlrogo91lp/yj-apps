import Foundation

/// **import 의 불변조건이 사는 자리다** (스펙 3절 · 잔디 스펙 6절).
///
/// 이미 `healthKitUUID` 를 가진 레코드는 통과시킨다 — 갱신도 하지 않는다. 덮어쓰면
/// 워치가 잰 시간(정지 제외)이 HealthKit 이 잰 시간으로 바뀌어 **과거 잔디 농도가
/// 소급해서 달라지고**, 세그먼트·부위·메모까지 날아간다.
///
/// **삭제는 다루지 않는다** — 건강 앱에서 지워진 워크아웃을 따라 지우는 일은 3개 앱에
/// 걸리는 문제라 YJKit 범위로 옮겼다 (스펙 4절). 그때 이 타입에 `deletions` 가 돌아온다.
nonisolated enum WorkoutImportPlanner {
    static func inserts(from imported: [ImportedWorkout],
                        existing: Set<UUID>) -> [ImportedWorkout]
    {
        // 순서를 지키며 중복을 접는다 — Set 으로 바꾸면 삽입 순서가 실행마다 달라진다.
        var seen = Set<UUID>()
        return imported.filter { workout in
            guard !existing.contains(workout.uuid) else { return false }
            return seen.insert(workout.uuid).inserted
        }
    }
}
