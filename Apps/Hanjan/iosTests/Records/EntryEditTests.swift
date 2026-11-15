import Foundation
@testable import Hanjan
import Testing

struct EntryEditTests {
    private let sessionId = UUID()
    private let now = Date(timeIntervalSince1970: 10000)

    private func count(_ entries: [DrinkEntry], _ kind: DrinkKind) -> Int {
        entries.count(where: { $0.kindId == kind.id && !$0.isToastOnly })
    }

    @Test func increase_addsEntriesWithNewIds() {
        let original = [entry(1, sessionId: sessionId), entry(2, sessionId: sessionId)]
        let result = EntryEdit.adjust(original, kind: DrinkPresets.soju, to: 4, sessionId: sessionId, now: now)
        #expect(count(result, DrinkPresets.soju) == 4)
        #expect(Set(original.map(\.id)).isSubset(of: Set(result.map(\.id))))
        let added = result.filter { entry in !original.contains { $0.id == entry.id } }
        #expect(added.count == 2)
        #expect(Set(added.map(\.id)).count == 2)
        #expect(added.allSatisfy { $0.sessionId == sessionId && $0.loggedAt == now && !$0.isToastOnly })
        #expect(added.allSatisfy { abs($0.alcoholGrams - DrinkPresets.soju.alcoholGrams) < 0.0001 })
    }

    @Test func decrease_removesMostRecentFirst() {
        let first = entry(1, sessionId: sessionId)
        let second = entry(2, sessionId: sessionId)
        let third = entry(3, sessionId: sessionId)
        let result = EntryEdit.adjust([third, first, second], kind: DrinkPresets.soju, to: 1, sessionId: sessionId, now: now)
        #expect(result.map(\.id) == [first.id])
    }

    @Test func belowZero_stopsAtZero() {
        let original = [entry(1, sessionId: sessionId), entry(2, sessionId: sessionId)]
        let result = EntryEdit.adjust(original, kind: DrinkPresets.soju, to: -3, sessionId: sessionId, now: now)
        #expect(result.isEmpty)
    }

    @Test func otherKindsAndToastOnly_untouched() {
        let beer = entry(1, kind: DrinkPresets.beer, sessionId: sessionId)
        let toast = entry(2, toast: true, sessionId: sessionId)
        let soju = entry(3, sessionId: sessionId)
        let result = EntryEdit.adjust([beer, toast, soju], kind: DrinkPresets.soju, to: 0, sessionId: sessionId, now: now)
        #expect(Set(result.map(\.id)) == [beer.id, toast.id])
    }

    @Test func toastOnlyOfSameKind_notCountedOrRemoved() {
        let toast = entry(5, toast: true, sessionId: sessionId)
        let soju = entry(1, sessionId: sessionId)
        let result = EntryEdit.adjust([soju, toast], kind: DrinkPresets.soju, to: 0, sessionId: sessionId, now: now)
        #expect(result.map(\.id) == [toast.id])
    }

    @Test func sameCount_returnsSameEntries() {
        let original = [entry(1, sessionId: sessionId), entry(2, kind: DrinkPresets.beer, sessionId: sessionId)]
        let result = EntryEdit.adjust(original, kind: DrinkPresets.soju, to: 1, sessionId: sessionId, now: now)
        #expect(result == original)
    }
}
