import Foundation
import Testing
@testable import ConnectivityCore

struct MessageRouterTests {
    @Test func routesToMatchingTypeOnly() {
        let router = MessageRouter()
        var scoreDelivered = false
        var endDelivered = false
        router.register(type: "a", maxAge: nil) { _ in scoreDelivered = true }
        router.register(type: "b", maxAge: nil) { _ in endDelivered = true }
        router.route(["type": "a"])
        #expect(scoreDelivered == true)
        #expect(endDelivered == false)
    }

    @Test func unknownOrMissingTypeIsIgnored() {
        let router = MessageRouter()
        var delivered = false
        router.register(type: "a", maxAge: nil) { _ in delivered = true }
        router.route(["type": "unknown"])
        router.route([:])
        #expect(delivered == false)
    }

    @Test func freshMessagePassesMaxAgeFilter() {
        let router = MessageRouter()
        var delivered = false
        router.register(type: "end", maxAge: 60) { _ in delivered = true }
        let now = 1_000_000.0
        router.route(["type": "end", "sentAt": now - 1], now: now)
        #expect(delivered == true)
    }

    @Test func staleMessageIsDroppedByMaxAgeFilter() {
        let router = MessageRouter()
        var delivered = false
        router.register(type: "end", maxAge: 60) { _ in delivered = true }
        let now = 1_000_000.0
        router.route(["type": "end", "sentAt": now - 120], now: now)
        #expect(delivered == false)
    }

    @Test func missingSentAtIsNotStale() {
        let router = MessageRouter()
        var delivered = false
        router.register(type: "end", maxAge: 60) { _ in delivered = true }
        router.route(["type": "end"], now: 1_000_000.0)
        #expect(delivered == true)
    }

    @Test func multipleHandlersForSameTypeAllReceive() {
        let router = MessageRouter()
        var first = false
        var second = false
        router.register(type: "a", maxAge: nil) { _ in first = true }
        router.register(type: "a", maxAge: nil) { _ in second = true }
        router.route(["type": "a"])
        #expect(first == true)
        #expect(second == true)
    }

    @Test func maxAgeAppliesPerRegistration() {
        let router = MessageRouter()
        var filtered = false
        var unfiltered = false
        router.register(type: "end", maxAge: 60) { _ in filtered = true }
        router.register(type: "end", maxAge: nil) { _ in unfiltered = true }
        let now = 1_000_000.0
        router.route(["type": "end", "sentAt": now - 120], now: now)
        #expect(filtered == false)
        #expect(unfiltered == true)
    }

    @Test func stampOverwritesTypeAndAddsSentAt() {
        let stamped = MessageEnvelope.stamp(["type": "wrong", "payload": 1], type: "right", sentAt: 42)
        #expect(stamped["type"] as? String == "right")
        #expect(stamped["sentAt"] as? Double == 42)
        #expect(stamped["payload"] as? Int == 1)
    }
}
