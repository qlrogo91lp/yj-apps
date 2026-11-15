import Foundation

/// 기록 상세의 술별 스테퍼. 짠만 기록은 세지도 지우지도 않는다.
nonisolated enum EntryEdit {
    /// `kind` 의 마신 잔 수를 `count` 로 맞춘 기록 목록을 돌려준다.
    /// 늘리면 새 id 로 `now` 시각의 잔을 덧붙이고, 줄이면 가장 최근 잔부터 지운다. 0 아래로 내려가지 않는다.
    static func adjust(_ entries: [DrinkEntry], kind: DrinkKind, to count: Int, sessionId: UUID, now: Date) -> [DrinkEntry] {
        let target = max(0, count)
        let matching = entries
            .filter { $0.kindId == kind.id && !$0.isToastOnly }
            .sorted { $0.loggedAt == $1.loggedAt ? $0.id.uuidString < $1.id.uuidString : $0.loggedAt < $1.loggedAt }
        if matching.count > target {
            let removed = Set(matching.suffix(matching.count - target).map(\.id))
            return entries.filter { !removed.contains($0.id) }
        }
        let added = (0 ..< (target - matching.count)).map { _ in
            DrinkEntry(
                id: UUID(),
                sessionId: sessionId,
                kindId: kind.id,
                kindName: kind.name,
                alcoholGrams: kind.alcoholGrams,
                loggedAt: now,
                source: .phone,
                isToastOnly: false
            )
        }
        return entries + added
    }
}
