import Foundation
import WidgetKit

/// 스냅샷 저장/삭제와 컴플리케이션 타임라인 갱신을 한 동작으로 묶는다 (spec §7).
/// ViewModel은 이 프로토콜에만 의존해, 테스트에서 WidgetKit 부작용 없이 호출 여부를 검증한다.
protocol RoundSnapshotPublishing {
    func publish(_ snapshot: RoundSnapshot)
    func clear()
    func loadCurrent() -> RoundSnapshot?
}

struct RoundSnapshotPublisher: RoundSnapshotPublishing {
    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = RoundSnapshotStore.appGroupDefaults) {
        self.defaults = defaults
    }

    func publish(_ snapshot: RoundSnapshot) {
        RoundSnapshotStore.save(snapshot, to: defaults)
        reloadComplication()
    }

    func clear() {
        RoundSnapshotStore.clear(from: defaults)
        reloadComplication()
    }

    func loadCurrent() -> RoundSnapshot? {
        RoundSnapshotStore.load(from: defaults)
    }

    /// 컴플리케이션 타임라인 정책이 `.never`라, 이 호출이 갱신의 유일한 트리거다 (plan ②).
    private func reloadComplication() {
        #if os(watchOS)
            WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
