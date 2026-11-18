import ConnectivityCore
import Foundation

nonisolated struct SessionStartMessage: ConnectivityMessage, Codable, Equatable, Sendable {
    static let messageType = "hanjan.SessionStartMessage"
    let session: LiveSession
    init(session: LiveSession) {
        self.session = session
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
