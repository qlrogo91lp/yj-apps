import Foundation

nonisolated enum SessionSnapshotStore {
    static let appGroup = "group.com.yj.Hanjan"
    private static let key = "sessionSnapshot"
    static func write(_ snapshot: SessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: appGroup)?.set(data, forKey: key)
    }

    static func read() -> SessionSnapshot {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key), let snapshot = try? JSONDecoder().decode(
            SessionSnapshot.self,
            from: data
        ) else { return .idle }
        return snapshot
    }
}
