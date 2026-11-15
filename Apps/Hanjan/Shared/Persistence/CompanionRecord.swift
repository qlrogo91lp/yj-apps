import Foundation
import SwiftData

@Model final class CompanionRecord {
    var id: UUID = UUID()
    var name: String = ""
    var sessions: [SessionRecord]?
    init(id: UUID = UUID(), name: String = "") {
        self.id = id; self.name = name
    }
}
