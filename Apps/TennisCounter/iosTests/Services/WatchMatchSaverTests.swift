import Foundation
import MonitoringCore
@testable import TennisCounter
import Testing

@MainActor
struct WatchMatchSaverTests {
    private func message(sessionId: UUID = UUID(), matchId: UUID? = nil) -> MatchEndMessage {
        MatchEndMessage(
            sessionId: sessionId,
            result: "win",
            completedSets: [[6, 4]],
            startedAt: Date(timeIntervalSince1970: 1_000_000),
            endedAt: Date(timeIntervalSince1970: 1_001_800),
            durationSeconds: 1800,
            calories: 200,
            averageHeartRate: 130,
            mode: "oneSet",
            noAdRule: true,
            matchId: matchId
        )
    }

    private func makeSaver(store: MatchUpserting,
                           crashReporter: CrashReporting = CrashReportingSpy(),
                           acks: AckBox = AckBox()) -> WatchMatchSaver
    {
        WatchMatchSaver(store: store, crashReporter: crashReporter, sendResult: { acks.sent.append($0) })
    }

    final class AckBox {
        var sent: [MatchSaveResultMessage] = []
    }

    @Test func saveFromWatchPersistsMatch() throws {
        let persistence = try TestPersistence.make()
        let sid = UUID()

        makeSaver(store: persistence.matches).save(message(sessionId: sid))

        #expect(try persistence.matches.fetchByWorkoutSession(sid).count == 1)
    }

    @Test func saveSendsSuccessAck() {
        let acks = AckBox()
        let sid = UUID()

        makeSaver(store: MatchStoreStub(), acks: acks).save(message(sessionId: sid))

        #expect(acks.sent.count == 1)
        #expect(acks.sent.first?.sessionId == sid)
        #expect(acks.sent.first?.success == true)
    }

    @Test func saveFailureSendsFailureAck() {
        let store = MatchStoreStub()
        store.shouldFail = true
        let acks = AckBox()

        makeSaver(store: store, acks: acks).save(message())

        #expect(acks.sent.count == 1)
        #expect(acks.sent.first?.success == false)
    }

    @Test func watchSaveFailureIsRecordedAsNonFatal() {
        let store = MatchStoreStub()
        store.shouldFail = true
        let spy = CrashReportingSpy()
        let sid = UUID()

        makeSaver(store: store, crashReporter: spy).save(message(sessionId: sid))

        let recorded = spy.calls.compactMap { call -> (String, Int, [String: String])? in
            if case let .record(domain, code, context) = call { return (domain, code, context) }
            return nil
        }
        #expect(recorded.count == 1)
        #expect(recorded.first?.0 == "Ralli.Save")
        #expect(recorded.first?.1 == 2)
        #expect(recorded.first?.2["source"] == "watch")
        #expect(recorded.first?.2["sessionId"] == sid.uuidString)
        #expect(spy.calls.contains(.log("save attempted (watch)")))
    }

    @Test func duplicateDeliveryKeepsOneMatch() throws {
        let persistence = try TestPersistence.make()
        let sid = UUID()
        // 중복 키는 matchId 다 — 실제 워치 메시지는 항상 싣는다
        let msg = message(sessionId: sid, matchId: UUID())
        let saver = makeSaver(store: persistence.matches)

        saver.save(msg)
        saver.save(msg)

        #expect(try persistence.matches.fetchByWorkoutSession(sid).count == 1)
    }
}
