@testable import Hanjan
import Testing

struct LimitLevelTests {
    @Test func levels() {
        #expect(LimitLevel.of(equivalent: 6.3, limit: 8) == .normal); #expect(LimitLevel
            .of(equivalent: 6.4, limit: 8) == .warning); #expect(LimitLevel.of(
            equivalent: 8,
            limit: 8
        ) == .reached); #expect(LimitLevel.of(equivalent: 8.1, limit: 8) == .exceeded); #expect(
            LimitLevel.of(equivalent: 1, limit: 0) == .reached
        )
    }

    @Test func crossings() {
        #expect(LimitLevel.crossed(from: .normal, to: .warning) == .warning); #expect(LimitLevel.crossed(
            from: .warning,
            to: .warning
        ) == nil); #expect(LimitLevel.crossed(from: .reached, to: .exceeded) == nil)
    }
}
