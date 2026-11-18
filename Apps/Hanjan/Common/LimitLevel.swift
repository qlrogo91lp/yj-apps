import Foundation

nonisolated enum LimitLevel: Equatable, Codable, Sendable {
    case normal, warning, reached, exceeded
    static func of(equivalent: Double, limit: Double) -> LimitLevel {
        let safeLimit = limit.isFinite ? max(1, limit) : 1
        guard equivalent.isFinite else { return .normal }
        if equivalent > safeLimit { return .exceeded }
        if equivalent >= safeLimit { return .reached }
        if equivalent >= safeLimit * 0.8 { return .warning }
        return .normal
    }

    static func crossed(from: LimitLevel, to: LimitLevel) -> LimitLevel? {
        let levels: [LimitLevel] = [.normal, .warning, .reached, .exceeded]
        guard let old = levels.firstIndex(of: from), let new = levels.firstIndex(of: to), new > old else { return nil }
        if to == .warning || to == .reached { return to }
        if to == .exceeded, old < 2 { return .reached }
        return nil
    }
}
