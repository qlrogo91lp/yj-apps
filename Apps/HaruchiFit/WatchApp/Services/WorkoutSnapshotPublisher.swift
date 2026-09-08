import Foundation
import WidgetKit

/// 진행 중 세션 상태를 컴플리케이션에 내보내는 통로.
///
/// **저장과 타임라인 갱신을 한 동작으로 묶는다.** 둘이 갈리면 저장은 됐는데 갱신을 안 부른
/// 경로가 생기고, 컴플리케이션 타임라인 정책이 `.never` 라 그러면 화면이 영영 안 바뀐다.
///
/// 뷰모델은 이 프로토콜에만 의존한다 — 테스트에서 WidgetKit 부작용 없이 호출 시점을 본다.
protocol WorkoutSnapshotPublishing {
    func publish(_ snapshot: WorkoutSnapshot)
    func clear()
}

/// `nonisolated` 인 이유 — 이 타깃은 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 라 표시가
/// 없으면 MainActor 가 된다. 그러면 `WorkoutViewModel.init` 의 기본 인자(비격리 문맥에서
/// 평가된다)에서 이 이니셜라이저를 부를 수 없다.
///
/// class 가 아니라 struct 인 이유 — `nonisolated final class` 는 swiftlint 과 swiftformat 이
/// 서로 반대 순서를 요구해 `make fix` 가 무한히 되돌린다. struct 는 `final` 이 없어 충돌하지 않고,
/// 골프의 `RoundSnapshotPublisher` 도 struct 다.
nonisolated struct WorkoutSnapshotPublisher: WorkoutSnapshotPublishing {
    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = WorkoutSnapshotStore.appGroupDefaults) {
        self.defaults = defaults
    }

    func publish(_ snapshot: WorkoutSnapshot) {
        WorkoutSnapshotStore.save(snapshot, to: defaults)
        reloadComplication()
    }

    func clear() {
        WorkoutSnapshotStore.clear(from: defaults)
        reloadComplication()
    }

    /// 타임라인 정책이 `.never` 라 이 호출이 갱신의 유일한 트리거다 (제품 스펙 WC절).
    private func reloadComplication() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
