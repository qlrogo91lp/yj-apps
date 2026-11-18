import Foundation
@testable import TennisCounter_Watch_App
import Testing

@MainActor
struct MatchSaveOutboxTests {
    /// 보관함에 넣은 시각을 테스트가 움직인다.
    final class Clock {
        var date = Date(timeIntervalSince1970: 2_000_000_000)
    }

    /// `send` 호출을 쌓는다. `result` 가 WCSession 을 실제로 불렀는지(`ConnectivityService.send` 의 반환값)를 흉내 낸다.
    final class SendSpy {
        var result = true
        private(set) var sent: [MatchEndMessage] = []

        func send(_ message: MatchEndMessage) -> Bool {
            sent.append(message)
            return result
        }
    }

    private static let day: TimeInterval = 24 * 3600

    /// 테스트마다 새 저장소를 쓴다 — 표준 저장소를 쓰면 병렬로 도는 테스트와 섞인다.
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: UUID().uuidString)!
    }

    private func makeOutbox(defaults: UserDefaults, spy: SendSpy, clock: Clock) -> MatchSaveOutbox {
        MatchSaveOutbox(defaults: defaults, send: { spy.send($0) }, now: { clock.date })
    }

    private func message(
        sessionId: UUID = UUID(),
        matchId: UUID = UUID(),
        endedAt: Date = Date(timeIntervalSince1970: 2_000_000_000)
    ) -> MatchEndMessage {
        MatchEndMessage(
            sessionId: sessionId,
            result: "win",
            completedSets: [[6, 4]],
            startedAt: endedAt.addingTimeInterval(-1800),
            endedAt: endedAt,
            durationSeconds: 1800,
            calories: 200,
            averageHeartRate: 130,
            mode: "oneSet",
            noAdRule: true,
            matchId: matchId
        )
    }

    @Test func enqueueStoresAndSendsOnce() {
        let spy = SendSpy()
        let outbox = makeOutbox(defaults: makeDefaults(), spy: spy, clock: Clock())
        let mid = UUID()

        outbox.enqueue(message(matchId: mid))

        #expect(outbox.pendingMatchIds == [mid])
        #expect(spy.sent.count == 1)
        #expect(spy.sent.first?.matchId == mid)
    }

    /// 워치 앱이 종료돼도 기록이 남아야 다음 실행에서 다시 보낸다.
    @Test func enqueueSurvivesNewInstance() {
        let defaults = makeDefaults()
        let mid = UUID()
        makeOutbox(defaults: defaults, spy: SendSpy(), clock: Clock()).enqueue(message(matchId: mid))

        let relaunched = makeOutbox(defaults: defaults, spy: SendSpy(), clock: Clock())

        #expect(relaunched.pendingMatchIds == [mid])
    }

    @Test func successAckWithMatchIdRemovesOnlyThatMatch() {
        let outbox = makeOutbox(defaults: makeDefaults(), spy: SendSpy(), clock: Clock())
        let sid = UUID(), first = UUID(), second = UUID()
        outbox.enqueue(message(sessionId: sid, matchId: first))
        outbox.enqueue(message(sessionId: sid, matchId: second))

        outbox.acknowledge(MatchSaveResultMessage(sessionId: sid, success: true, matchId: first))

        #expect(outbox.pendingMatchIds == [second])
    }

    /// Review Focus 1 — 구버전 폰(1.2.0)의 ACK 에는 matchId 가 없다. 같은 세션 항목을 지우지 않으면
    /// 14일 동안 계속 다시 보낸다.
    @Test func successAckWithoutMatchIdRemovesWholeSession() {
        let outbox = makeOutbox(defaults: makeDefaults(), spy: SendSpy(), clock: Clock())
        let sid = UUID(), other = UUID()
        outbox.enqueue(message(sessionId: sid))
        outbox.enqueue(message(sessionId: sid))
        outbox.enqueue(message(sessionId: other, matchId: other))

        outbox.acknowledge(MatchSaveResultMessage(sessionId: sid, success: true))

        #expect(outbox.pendingMatchIds == [other])
    }

    /// Review Focus 4 — 폰 저장 실패는 항목을 남기고 다음 기회에 바로 다시 보낸다.
    @Test func failedAckKeepsEntryAndResendsOnNextFlush() {
        let spy = SendSpy()
        let clock = Clock()
        let outbox = makeOutbox(defaults: makeDefaults(), spy: spy, clock: clock)
        let sid = UUID(), mid = UUID()
        outbox.enqueue(message(sessionId: sid, matchId: mid))

        outbox.acknowledge(MatchSaveResultMessage(sessionId: sid, success: false, matchId: mid))
        clock.date += 1
        outbox.flush()

        #expect(outbox.pendingMatchIds == [mid])
        #expect(spy.sent.count == 2)
    }

    @Test func flushDoesNotResendWithinInterval() {
        let spy = SendSpy()
        let clock = Clock()
        let outbox = makeOutbox(defaults: makeDefaults(), spy: spy, clock: clock)
        outbox.enqueue(message())

        clock.date += 59
        outbox.flush()

        #expect(spy.sent.count == 1)
    }

    @Test func flushResendsAfterInterval() {
        let spy = SendSpy()
        let clock = Clock()
        let outbox = makeOutbox(defaults: makeDefaults(), spy: spy, clock: clock)
        outbox.enqueue(message())

        clock.date += 60
        outbox.flush()

        #expect(spy.sent.count == 2)
    }

    /// Review Focus 5 — 활성화 전(앱 시작 직후)에 보내면 `send` 가 false 다. 보낸 것으로 치지 않고
    /// 다음 flush(활성화 완료)에서 간격을 기다리지 않고 바로 보낸다.
    @Test func unsentEntryIsSentOnNextFlushImmediately() {
        let spy = SendSpy()
        spy.result = false
        let clock = Clock()
        let outbox = makeOutbox(defaults: makeDefaults(), spy: spy, clock: clock)
        let mid = UUID()
        outbox.enqueue(message(matchId: mid))

        spy.result = true
        clock.date += 1
        outbox.flush()

        #expect(spy.sent.count == 2)
        #expect(outbox.pendingMatchIds == [mid])
    }

    /// Review Focus 3 — 읽을 수 없는 항목(형식 변경·손상)은 그것만 버리고 나머지는 보낸다.
    @Test func flushDropsExpiredAndUnreadableEntries() {
        let defaults = makeDefaults()
        let spy = SendSpy()
        spy.result = false // 넣을 때는 못 보낸 상태로 둔다 — flush 가 보내는 것만 센다
        let clock = Clock()
        let outbox = makeOutbox(defaults: defaults, spy: spy, clock: clock)
        let expired = UUID(), fresh = UUID()
        outbox.enqueue(message(matchId: expired, endedAt: clock.date - 15 * Self.day))
        outbox.enqueue(message(matchId: fresh, endedAt: clock.date))
        var stored = defaults.array(forKey: "pendingMatchSaves") ?? []
        stored.append(["payload": ["type": "matchSave"]])
        defaults.set(stored, forKey: "pendingMatchSaves")

        spy.result = true
        let sentBeforeFlush = spy.sent.count
        outbox.flush()

        #expect(outbox.pendingMatchIds == [fresh])
        #expect(spy.sent.dropFirst(sentBeforeFlush).map(\.matchId) == [fresh])
        #expect((defaults.array(forKey: "pendingMatchSaves") ?? []).count == 1)
    }
}
