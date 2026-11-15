import Foundation
@testable import Hanjan
import Testing

struct MessageRoundTripTests {
    @Test func roundTrips() {
        var s = session(); for i in 0 ..<
            30
        {
            s.ledger.add(entry(Double(i)))
        }; let start = SessionStartMessage(session: s); let end = SessionEndMessage(
            sessionId: s.id,
            endedAt: Date()
        ); let add = EntryAddMessage(entry: entry()); let remove = EntryRemoveMessage(sessionId: s.id,
                                                                                      entryId: UUID()); let state = SessionStateMessage(
            session: s
        ); let config = ConfigMessage(
            kinds: DrinkPresets.all,
            limit: 8
        ); #expect(
            SessionStartMessage(from: start.toDictionary()) == start
        ); #expect(SessionEndMessage(from: end.toDictionary()) ==
            end); #expect(EntryAddMessage(from: add.toDictionary()) == add); #expect(EntryRemoveMessage(from: remove.toDictionary()) ==
            remove); #expect(SessionStateMessage(from: state.toDictionary()) == state); #expect(ConfigMessage(from: config.toDictionary()) == config)
    }
}
