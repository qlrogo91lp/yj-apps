import Foundation

nonisolated struct DrinkKind: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var abv: Double
    var volumeML: Double
    var isPreset: Bool
    var sortOrder: Int
    var alcoholGrams: Double {
        guard abv.isFinite, volumeML.isFinite, abv > 0, volumeML > 0 else { return 0 }
        let result = volumeML * abv / 100 * 0.789
        return result.isFinite ? result : 0
    }
}
