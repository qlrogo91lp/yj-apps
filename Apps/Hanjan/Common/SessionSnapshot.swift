import Foundation

nonisolated struct SessionSnapshot: Codable, Equatable, Sendable {
    let isActive: Bool
    let equivalent: Double
    let limit: Double
    let kindName: String
    let updatedAt: Date
    static let idle = SessionSnapshot(isActive: false, equivalent: 0, limit: 8, kindName: "", updatedAt: .distantPast)
}
