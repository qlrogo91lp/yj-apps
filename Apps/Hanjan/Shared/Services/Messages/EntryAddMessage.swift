import ConnectivityCore
import Foundation

nonisolated struct EntryAddMessage: ConnectivityMessage, Codable, Equatable, Sendable {
    static let messageType = "hanjan.EntryAddMessage"
    let entry: DrinkEntry
    init(entry: DrinkEntry) {
        self.entry = entry
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
