import Foundation
@testable import Hanjan
import Testing

struct LiveSessionTests {
    @Test func toastEvery3_drinksOnThirdTap() {
        var s = session(); s
            .setToast(every: 3, at: Date(timeIntervalSince1970: 0)); for i in 1 ... 3
        {
            #expect(s.toastProgress?.filled == i); let e = s.makeEntry(
                id: UUID(),
                at: Date(timeIntervalSince1970: Double(i)),
                kind: DrinkPresets.soju,
                source: .phone
            ); #expect(e.isToastOnly == (i != 3)); s.ledger.add(e)
        }; #expect(s.toastProgress?.filled == 1)
    }

    @Test func toastEvery2_undoRestoresTurn() throws {
        var s = session(); s.setToast(every: 2, at: s.startedAt); for i in 1 ... 2 {
            s.ledger.add(s.makeEntry(
                id: UUID(),
                at: s.startedAt.addingTimeInterval(Double(i)),
                kind: DrinkPresets.soju,
                source: .phone
            ))
        }; try s.ledger.remove(id: #require(s.ledger.last?.id)); #expect(s.toastProgress?.isDrinkTurn == true)
    }

    @Test func toastOff_alwaysDrink() {
        let s = session(); #expect(s.toastProgress == nil); #expect(!s.makeEntry(
            id: UUID(),
            at: Date(),
            kind: DrinkPresets.soju,
            source: .phone
        ).isToastOnly)
    }

    @Test func setToastMidSession_restartsCycle() {
        var s = session(); for i in 1 ... 5 {
            s.ledger.add(entry(Double(i)))
        }; s.setToast(
            every: 3,
            at: Date(timeIntervalSince1970: 6)
        ); #expect(s.toastProgress?.filled == 1); s.ledger.add(entry(7)); s.ledger.add(entry(8)); #expect(s.toastProgress?.isDrinkTurn == true)
    }

    @Test func merging_laterToastChangeWins() {
        var a = session(); var b = a; a.setToast(every: 2, at: Date(timeIntervalSince1970: 1)); b.setToast(
            every: 3,
            at: Date(timeIntervalSince1970: 2)
        ); #expect(a.merging(b).toast == b.toast)
    }

    @Test func lateEntryAfterEnd_mergesIntoEndedSession() {
        var a = session(); var b = a; a.endedAt = Date(); b.ledger.add(entry()); let merged = a
            .merging(b); #expect(merged.endedAt == a.endedAt); #expect(merged.ledger.activeEntries.count == 1)
    }

    @Test func absorbing_keepsEarlierIdAndAllEntries() {
        var a = session(0); var b = session(10); a.ledger.add(entry()); b.ledger.add(entry()); let result = b
            .absorbing(a); #expect(result.id == a.id); #expect(result.ledger.activeEntries.count == 2)
    }

    @Test func shouldAutoEnd_after3HoursFromLastEntry() {
        var s = session(); s.ledger
            .add(entry(10)); #expect(!s.shouldAutoEnd(now: Date(timeIntervalSince1970: 10 + 10740))); #expect(s
                .shouldAutoEnd(now: Date(timeIntervalSince1970: 10 + 10800)))
    }
}
