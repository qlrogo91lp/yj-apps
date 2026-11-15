import ActivityKit
import Foundation

nonisolated struct HanjanActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var kindName: String
        var equivalent: Double
        var limit: Double
        var toastFilled: Int?
        var toastTotal: Int?
        var toastOnly: Bool
    }

    let sessionId: UUID
}
