import Combine
import Foundation

/// 홈 화면의 상태. 복구 판단을 View 밖으로 빼 테스트 가능하게 한다 (spec §6).
/// UI 프레임워크를 import하지 않는다.
@MainActor
final class HomeViewModel: ObservableObject {
    /// 라운드 시작 시 쓸 홀 수. 앱을 열 때마다 18로 시작하며 영속 저장하지 않는다 (spec §3.4).
    @Published private(set) var holeCount = 18
    /// 복구할 스냅샷. nil이 아니면 그 라운드를 이어서 연다.
    @Published private(set) var resumingSnapshot: RoundSnapshot?
    @Published var isRoundActive = false

    private let publisher: RoundSnapshotPublishing

    /// 복구 시도는 앱 실행당 1회다 (spec §2 결정 7). 없으면 요약에서 전송 없이 나왔을 때
    /// 홈에 도착하자마자 다시 라운드로 끌려 들어가 빠져나올 수 없다.
    private var hasAttemptedResume = false

    init(publisher: RoundSnapshotPublishing = RoundSnapshotPublisher()) {
        self.publisher = publisher
    }

    /// 진행 중 스냅샷이 남아 있는지. 새 라운드 시작 전 확인 다이얼로그를 띄울지 판단한다 (spec §3.6).
    var hasPendingRound: Bool {
        publisher.loadCurrent() != nil
    }

    func resumeIfNeeded() {
        guard !hasAttemptedResume else { return }
        hasAttemptedResume = true
        guard let snapshot = publisher.loadCurrent() else { return }
        resumingSnapshot = snapshot
        isRoundActive = true
    }

    func toggleHoleCount() {
        holeCount = holeCount == 18 ? 9 : 18
    }

    func startNewRound() {
        resumingSnapshot = nil
        isRoundActive = true
    }
}
