import Foundation
import SwiftData

@Model final class DrinkKindRecord {
    var id: UUID = UUID()
    var name: String = ""
    var abv: Double = 0
    var volumeML: Double = 0
    var isPreset: Bool = false
    var sortOrder: Int = 0
    init(id: UUID = UUID(), name: String = "", abv: Double = 0, volumeML: Double = 0, isPreset: Bool = false, sortOrder: Int = 0) {
        self.id = id; self.name = name; self.abv = abv; self.volumeML = volumeML; self.isPreset = isPreset; self.sortOrder = sortOrder
    }
}
