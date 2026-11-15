import Foundation

nonisolated struct DrinkEntry: Identifiable, Hashable, Codable, Sendable {
    enum Source: String, Codable, Sendable { case phone, watch }
    let id: UUID
    let sessionId: UUID
    let kindId: UUID
    let kindName: String
    let alcoholGrams: Double
    let loggedAt: Date
    let source: Source
    let isToastOnly: Bool
    init(id: UUID, sessionId: UUID, kindId: UUID, kindName: String, alcoholGrams: Double, loggedAt: Date, source: Source, isToastOnly: Bool) {
        self.id = id; self.sessionId = sessionId; self.kindId = kindId; self.kindName = kindName
        self.alcoholGrams = isToastOnly ? 0 : alcoholGrams; self.loggedAt = loggedAt; self.source = source; self.isToastOnly = isToastOnly
    }

    private enum CodingKeys: String, CodingKey { case id, sessionId, kindId, kindName, alcoholGrams, loggedAt, source, isToastOnly }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: c.decode(UUID.self, forKey: .id),
            sessionId: c.decode(UUID.self, forKey: .sessionId),
            kindId: c.decode(UUID.self, forKey: .kindId),
            kindName: c.decode(String.self, forKey: .kindName),
            alcoholGrams: c.decode(Double.self, forKey: .alcoholGrams),
            loggedAt: c.decode(Date.self, forKey: .loggedAt),
            source: c.decode(Source.self, forKey: .source),
            isToastOnly: c.decodeIfPresent(Bool.self, forKey: .isToastOnly) ?? false
        )
    }
}
