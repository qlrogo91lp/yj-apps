import Foundation

nonisolated enum SojuFormat {
    static func string(_ equivalent: Double) -> String {
        guard equivalent.isFinite else { return "0" }
        let rounded = (equivalent * 2).rounded() / 2
        guard rounded.isFinite else { return "0" }
        return rounded.rounded() == rounded ? String(format: "%.0f", rounded) : String(format: "%.1f", rounded)
    }
}
