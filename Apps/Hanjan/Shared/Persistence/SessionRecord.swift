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
    /// 삭제된 잔 id (쉼표 구분 UUID). CloudKit 호환을 위해 문자열로 둔다
    var removedEntryIdsText: String = ""
    /// 이 기록에 합쳐진 세션 id (쉼표 구분 UUID)
    var mergedSessionIdsText: String = ""
    @Relationship(deleteRule: .cascade, inverse: \EntryRecord.session) var entries: [EntryRecord]?
    @Relationship(inverse: \CompanionRecord.sessions) var companions: [CompanionRecord]?
    init(id: UUID = UUID(), startedAt: Date = Date(), endedAt: Date? = nil, limit: Double = 8) {
        self.id = id; self.startedAt = startedAt; self.endedAt = endedAt; self.limit = limit
    }

    func apply(_ session: LiveSession) {
        id = session.id; startedAt = session.startedAt; endedAt = session.endedAt; limit = session.limit
        toastOnlyCount = session.ledger.activeEntries.filter(\.isToastOnly).count
        latitude = session.latitude; longitude = session.longitude; totalGrams = session.ledger.totalGrams
        removedEntryIds = session.ledger.removedIds; mergedSessionIds = session.mergedSessionIds
    }

    var removedEntryIds: Set<UUID> {
        get { Self.decodeIds(removedEntryIdsText) }
        set { removedEntryIdsText = Self.encodeIds(newValue) }
    }

    var mergedSessionIds: Set<UUID> {
        get { Self.decodeIds(mergedSessionIdsText) }
        set { mergedSessionIdsText = Self.encodeIds(newValue) }
    }

    /// 저장된 잔과 삭제 이력으로 장부를 복원한다. 보관된 세션에 늦은 메시지를 병합할 때 쓴다
    var ledger: DrinkLedger {
        let items = (entries ?? []).map {
            DrinkEntry(
                id: $0.id,
                sessionId: id,
                kindId: $0.kindId,
                kindName: $0.kindName,
                alcoholGrams: $0.alcoholGrams,
                loggedAt: $0.loggedAt,
                source: DrinkEntry.Source(rawValue: $0.source) ?? .phone,
                isToastOnly: $0.isToastOnly
            )
        }
        return DrinkLedger(entries: items, removedIds: removedEntryIds)
    }

    func owns(sessionId: UUID) -> Bool {
        sessionId == id || mergedSessionIds.contains(sessionId)
    }

    private static func encodeIds(_ ids: Set<UUID>) -> String {
        ids.map(\.uuidString).sorted().joined(separator: ",")
    }

    private static func decodeIds(_ text: String) -> Set<UUID> {
        Set(text.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
    }

    var sojuEquivalent: Double {
        totalGrams / DrinkPresets.soju.alcoholGrams
    }

    var limitLevel: LimitLevel {
        .of(equivalent: sojuEquivalent, limit: limit)
    }
}
