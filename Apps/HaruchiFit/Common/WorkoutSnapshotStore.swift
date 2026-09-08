import Foundation

/// App Group `UserDefaults` 에 진행 중 세션 스냅샷을 저장/로드한다.
/// **WidgetKit 갱신 호출은 여기 없다** — 이 타입은 저장만 하고, 묶는 것은 `WorkoutSnapshotPublisher` 다.
nonisolated enum WorkoutSnapshotStore {
    /// 워치 앱과 컴플리케이션 익스텐션 두 타깃이 선언한 그룹. 문자열이 어긋나면 조용히 못 읽는다.
    static let appGroupID = "group.com.yj.HaruchiFit"
    private static let key = "workoutSnapshot"

    static var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    @discardableResult
    static func save(_ snapshot: WorkoutSnapshot,
                     to defaults: UserDefaults? = WorkoutSnapshotStore.appGroupDefaults) -> Bool
    {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return false }
        defaults.set(data, forKey: key)
        return true
    }

    /// 디코딩 실패를 nil 로 떨어뜨린다. 여기서 던지면 컴플리케이션이 진행 중 세션을 통째로 잃는다.
    static func load(from defaults: UserDefaults? = WorkoutSnapshotStore.appGroupDefaults) -> WorkoutSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WorkoutSnapshot.self, from: data)
    }

    static func clear(from defaults: UserDefaults? = WorkoutSnapshotStore.appGroupDefaults) {
        defaults?.removeObject(forKey: key)
    }
}
