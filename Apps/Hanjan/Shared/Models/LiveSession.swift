import Foundation

nonisolated struct ToastSetting: Codable, Equatable, Sendable { let every: Int?; let changedAt: Date }
nonisolated struct ToastProgress: Codable, Equatable, Sendable {
    let filled: Int
    let total: Int
    var isDrinkTurn: Bool {
        filled == total
    }
}

nonisolated struct LiveSession: Identifiable, Codable, Equatable, Sendable {
    static let autoEndInterval: TimeInterval = 10800

    let id: UUID
    let startedAt: Date
    var endedAt: Date?
    var limit: Double
    var currentKindId: UUID
    var toast: ToastSetting
    var latitude: Double?
    var longitude: Double?
    var ledger: DrinkLedger
    /// absorbing 으로 이 세션에 합쳐진 다른 세션 id. 그 id 로 늦게 오는 메시지도 이 세션 것이다.
    var mergedSessionIds: Set<UUID>
    init(
        id: UUID,
        startedAt: Date,
        endedAt: Date? = nil,
        limit: Double,
        currentKindId: UUID,
        toast: ToastSetting? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        ledger: DrinkLedger = DrinkLedger(),
        mergedSessionIds: Set<UUID> = []
    ) {
        self.mergedSessionIds = mergedSessionIds
        self.id = id; self.startedAt = startedAt; self.endedAt = endedAt; self.limit = limit; self.currentKindId = currentKindId
        self.toast = toast ?? ToastSetting(every: nil, changedAt: startedAt); self.latitude = latitude; self.longitude = longitude; self
            .ledger = ledger
    }

    mutating func setToast(every: Int?, at: Date) {
        toast = ToastSetting(every: every, changedAt: at)
    }

    var toastProgress: ToastProgress? {
        guard let every = toast.every, every > 0 else { return nil }
        return ToastProgress(filled: ledger.activeEntries.count(where: { $0.loggedAt > toast.changedAt }) % every + 1, total: every)
    }

    func makeEntry(id: UUID, at: Date, kind: DrinkKind, source: DrinkEntry.Source) -> DrinkEntry {
        DrinkEntry(
            id: id,
            sessionId: self.id,
            kindId: kind.id,
            kindName: kind.name,
            alcoholGrams: kind.alcoholGrams,
            loggedAt: at,
            source: source,
            isToastOnly: toastProgress.map { !$0.isDrinkTurn } ?? false
        )
    }

    /// 이 세션 id 이거나 이 세션에 합쳐진 세션 id 면 true.
    func owns(sessionId: UUID) -> Bool {
        sessionId == id || mergedSessionIds.contains(sessionId)
    }

    var lastActivityAt: Date {
        ledger.last?.loggedAt ?? startedAt
    }

    func overlaps(_ other: LiveSession) -> Bool {
        lastActivityAt.addingTimeInterval(Self.autoEndInterval) >= other.startedAt &&
            other.lastActivityAt.addingTimeInterval(Self.autoEndInterval) >= startedAt
    }

    func shouldAutoEnd(now: Date) -> Bool {
        now.timeIntervalSince(lastActivityAt) >= Self.autoEndInterval
    }

    func merging(_ other: LiveSession) -> LiveSession {
        var result = self; result.ledger.merge(other.ledger); result.endedAt = endedAt ?? other.endedAt
        result.latitude = latitude ?? other.latitude; result.longitude = longitude ?? other.longitude
        if other.toast.changedAt > toast.changedAt { result.toast = other.toast }
        result.mergedSessionIds.formUnion(other.mergedSessionIds)
        if other.id != id { result.mergedSessionIds.insert(other.id) }
        return result
    }

    func absorbing(_ other: LiveSession) -> LiveSession {
        let earlier = startedAt <= other.startedAt ? self : other
        let later = startedAt <= other.startedAt ? other : self
        return earlier.merging(later)
    }
}
