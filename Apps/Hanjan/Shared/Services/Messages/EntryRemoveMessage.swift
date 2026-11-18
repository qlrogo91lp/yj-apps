import ConnectivityCore
import Foundation

nonisolated struct EntryRemoveMessage: ConnectivityMessage, Codable, Equatable, Sendable {
    static let messageType = "hanjan.EntryRemoveMessage"
    let sessionId: UUID
    let entryId: UUID
    init(sessionId: UUID, entryId: UUID) {
        self.sessionId = sessionId; self.entryId = entryId
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
