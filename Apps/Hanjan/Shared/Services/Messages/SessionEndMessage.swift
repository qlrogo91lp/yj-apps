import ConnectivityCore
import Foundation

nonisolated struct SessionEndMessage: ConnectivityMessage, Codable, Equatable, Sendable {
    static let messageType = "hanjan.SessionEndMessage"
    let sessionId: UUID
    let endedAt: Date
    init(sessionId: UUID, endedAt: Date) {
        self.sessionId = sessionId; self.endedAt = endedAt
    }

    init?(from dictionary: [String: Any]) {
        guard let data = dictionary["payload"] as? Data, let value = try? JSONDecoder().decode(Self.self, from: data) else { return nil }
        self = value
    }

    func toDictionary() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self) else { return [:] }
        return ["type": Self.messageType, "payload": data]
    }
}
