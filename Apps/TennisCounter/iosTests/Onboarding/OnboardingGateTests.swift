@testable import TennisCounter
import Testing

struct OnboardingGateTests {
    @Test func freshInstallShows() {
        #expect(OnboardingGate.shouldShow(seenVersion: 0))
    }

    @Test func seenCurrentVersionHides() {
        #expect(!OnboardingGate.shouldShow(seenVersion: OnboardingGate.version))
    }

    @Test func seenOlderVersionShowsAgain() {
        #expect(OnboardingGate.shouldShow(seenVersion: OnboardingGate.version - 1))
    }

    @Test func seenNewerVersionHides() {
        // 다운그레이드 등 — 미래 버전을 본 기록이면 띄우지 않는다
        #expect(!OnboardingGate.shouldShow(seenVersion: OnboardingGate.version + 1))
    }
}
