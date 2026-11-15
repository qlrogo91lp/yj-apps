import Foundation
import SwiftData

@Model final class SessionRecord {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var limit: Double = 8
    var toastOnlyCount: Int = 0
    var latitude: Double?
    var longitude: Double?
    var placeName: String?
    var condition: Int?
    var memo: String?
    var totalGrams: Double = 0
    @Relationship(deleteRule: .cascade, inverse: \EntryRecord.session) var entries: [EntryRecord]?
    @Relationship(inverse: \CompanionRecord.sessions) var companions: [CompanionRecord]?
    init(id: UUID = UUID(), startedAt: Date = Date(), endedAt: Date? = nil, limit: Double = 8) {
        self.id = id; self.startedAt = startedAt; self.endedAt = endedAt; self.limit = limit
    }

    func apply(_ session: LiveSession) {
        id = session.id; startedAt = session.startedAt; endedAt = session.endedAt; limit = session.limit
        toastOnlyCount = session.ledger.activeEntries.filter(\.isToastOnly).count
        latitude = session.latitude; longitude = session.longitude; totalGrams = session.ledger.totalGrams
    }

    var sojuEquivalent: Double {
        totalGrams / DrinkPresets.soju.alcoholGrams
    }

    var limitLevel: LimitLevel {
        .of(equivalent: sojuEquivalent, limit: limit)
    }
}
