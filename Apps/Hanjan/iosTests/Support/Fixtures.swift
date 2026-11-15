import Foundation
@testable import Hanjan

func entry(
    _ time: TimeInterval = 0,
    kind: DrinkKind = DrinkPresets.soju,
    toast: Bool = false,
    source: DrinkEntry.Source = .phone,
    sessionId: UUID = UUID()
) -> DrinkEntry {
    DrinkEntry(
        id: UUID(),
        sessionId: sessionId,
        kindId: kind.id,
        kindName: kind.name,
        alcoholGrams: toast ? 0 : kind.alcoholGrams,
        loggedAt: Date(timeIntervalSince1970: time),
        source: source,
        isToastOnly: toast
    )
}

func session(_ time: TimeInterval = 0) -> LiveSession {
    LiveSession(id: UUID(), startedAt: Date(timeIntervalSince1970: time), limit: 8, currentKindId: DrinkPresets.soju.id)
}
