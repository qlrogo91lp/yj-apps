import ConnectivityCore
import Foundation

nonisolated struct ConfigMessage: ConnectivityMessage, Codable, Equatable, Sendable {
    static let messageType = "hanjan.ConfigMessage"
    let kinds: [DrinkKind]
    let limit: Double
    init(kinds: [DrinkKind], limit: Double) {
        self.kinds = kinds; self.limit = limit
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
