import Foundation
@testable import Hanjan
import Testing

struct DrinkLedgerTests {
    @Test func removeBeforeAdd_neverCounts() {
        let e = entry(); var l = DrinkLedger(); l.remove(id: e.id); l.add(e); #expect(l.activeEntries.isEmpty)
    }

    @Test func duplicateAdd_countsOnce() {
        let e = entry(); var l = DrinkLedger(); l.add(e); l.add(e); #expect(l.activeEntries.count == 1)
    }

    @Test func merge_isCommutativeAndIdempotent() {
        var a = DrinkLedger(); var b = DrinkLedger(); a.add(entry()); b.add(entry()); var ab = a; ab.merge(b); var ba = b; ba
            .merge(a); #expect(ab == ba); var aa = a; aa.merge(a); #expect(aa == a)
    }

    @Test func last_isMostRecentAcrossSources() {
        var l = DrinkLedger(); l.add(entry(0)); let e = entry(300, source: .watch); l.add(e); #expect(l.last == e)
    }

    @Test func removeLastRepeatedly_stopsAtZero() {
        var l = DrinkLedger(); l.add(entry()); l
            .add(entry()); for _ in 0 ..< 3
        {
            if let last = l.last { l.remove(id: last.id) }
        }; #expect(l.activeEntries.isEmpty)
    }

    @Test func sojuEquivalent_mixedKinds() {
        var l = DrinkLedger(); l.add(entry()); l.add(entry()); l
            .add(entry(kind: DrinkPresets.beer)); #expect(abs(l
                    .sojuEquivalent() - (2 * DrinkPresets.soju.alcoholGrams + DrinkPresets.beer.alcoholGrams) / DrinkPresets.soju.alcoholGrams) <
                0.001)
    }

    @Test func zeroAbvKind_addsZeroGrams() {
        var kind = DrinkPresets.soju; kind.abv = 0; var l = DrinkLedger(); l
            .add(entry(kind: kind)); #expect(l.totalGrams == 0); #expect(!l.totalGrams.isNaN)
    }

    @Test func toastOnly_excludedFromGramsAndKindCounts() {
        var l = DrinkLedger(); l.add(entry(0, toast: true)); l.add(entry(1)); let last = entry(
            2,
            toast: true
        ); l
            .add(last); #expect(l.totalGrams == DrinkPresets.soju.alcoholGrams); #expect(l.drinkEntries.count == 1); #expect(l.activeEntries
                .count == 3); #expect(l.countsByKind().first?.count == 1); #expect(l.last == last)
    }
}
