import Foundation
@testable import HaruchiFit_Watch_App
import Testing

/// W0 — 홈에서 고른 시작 유형이 기억되고, 세션의 첫 구간이 그 유형으로 열린다.
@MainActor
struct StartKindTests {
    @Test("저장된 값이 없으면 근력으로 연다")
    func defaultsToStrength() {
        #expect(makeViewModel().mode == .strength)
    }

    @Test("토글하면 근력↔유산소가 번갈아 바뀐다")
    func toggleAlternates() {
        let viewModel = makeViewModel()

        viewModel.toggleStartKind()
        #expect(viewModel.mode == .cardio)

        viewModel.toggleStartKind()
        #expect(viewModel.mode == .strength)
    }

    @Test("토글한 유형은 다음 실행에서도 유지된다")
    func togglePersistsAcrossLaunches() {
        let defaults = freshDefaults()
        makeViewModel(defaults: defaults).toggleStartKind()

        #expect(makeViewModel(defaults: defaults).mode == .cardio)
    }

    @Test("저장된 값이 깨져 있으면 근력으로 연다")
    func brokenStoredValueFallsBack() {
        let defaults = freshDefaults()
        defaults.set("swimming", forKey: "startSegmentKind")

        #expect(makeViewModel(defaults: defaults).mode == .strength)
    }

    @Test("세션이 끝나지 않았으면 토글이 먹지 않는다")
    func toggleIgnoredOutsideIdle() {
        let viewModel = makeViewModel()
        viewModel.enterSummary(with: RecordFixture.make())

        viewModel.toggleStartKind()

        #expect(viewModel.mode == .strength)
    }

    // MARK: - Helpers

    /// 테스트마다 빈 저장소를 준다 — 하나가 남긴 값이 다음 테스트로 새면 순서에 의존하게 된다.
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "StartKindTests-\(UUID().uuidString)")!
    }

    private func makeViewModel(defaults: UserDefaults? = nil) -> WorkoutViewModel {
        WorkoutViewModel(connectivity: WorkoutRecordSendingSpy(),
                         remover: WorkoutRemovingSpy(),
                         defaults: defaults ?? freshDefaults())
    }
}
