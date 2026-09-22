import Foundation
import HealthKit

/// `HKQueryAnchor` 를 `UserDefaults` 에 둔다. 앵커가 없으면 **전체 히스토리**를 읽는다 —
/// 05 통계가 연도 아카이브라 과거를 자르면 그 화면이 빈 채로 나온다 (스펙 6절).
///
/// 디코딩이 실패하면 nil 로 떨어져 전체를 다시 읽는다. 중복은 플래너가 막으므로
/// 안전한 폴백이다.
struct WorkoutQueryAnchorStore {
    private let defaults: UserDefaults
    private let key = "healthKitWorkoutAnchor"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> HKQueryAnchor? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    func save(_ anchor: HKQueryAnchor) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor,
                                                           requiringSecureCoding: true)
        else { return }
        defaults.set(data, forKey: key)
    }
}
