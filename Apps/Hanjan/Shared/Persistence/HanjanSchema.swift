import SwiftData

enum HanjanSchema {
    static let models: [any PersistentModel.Type] = [SessionRecord.self, EntryRecord.self, DrinkKindRecord.self, CompanionRecord.self]
}
