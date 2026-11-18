import Foundation
import SwiftData

@Model final class EntryRecord {
    var id: UUID = UUID()
    var kindId: UUID = UUID()
    var kindName: String = ""
    var alcoholGrams: Double = 0
    var loggedAt: Date = Date()
    var source: String = "phone"
    var isToastOnly: Bool = false
    var session: SessionRecord?
    init(
        id: UUID = UUID(),
        kindId: UUID = UUID(),
        kindName: String = "",
        alcoholGrams: Double = 0,
        loggedAt: Date = Date(),
        source: String = "phone",
        isToastOnly: Bool = false,
        session: SessionRecord? = nil
    ) {
        self.id = id; self.kindId = kindId; self.kindName = kindName; self.alcoholGrams = alcoholGrams; self.loggedAt = loggedAt; self
            .source = source; self.isToastOnly = isToastOnly; self.session = session
    }
}
