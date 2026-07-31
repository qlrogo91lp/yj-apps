import Foundation

/// App Group UserDefaults에 진행 중 라운드 스냅샷을 저장/로드한다.
/// WidgetKit reload 호출은 호출부 책임 (이 타입은 순수 저장만).
enum RoundSnapshotStore {
    static let appGroupID = "group.com.yj.GolfCounter"
    private static let key = "roundSnapshot"

    static var appGroupDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func save(_ snapshot: RoundSnapshot, to defaults: UserDefaults? = RoundSnapshotStore.appGroupDefaults) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    static func load(from defaults: UserDefaults? = RoundSnapshotStore.appGroupDefaults) -> RoundSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RoundSnapshot.self, from: data)
    }

    static func clear(from defaults: UserDefaults? = RoundSnapshotStore.appGroupDefaults) {
        defaults?.removeObject(forKey: key)
    }
}
