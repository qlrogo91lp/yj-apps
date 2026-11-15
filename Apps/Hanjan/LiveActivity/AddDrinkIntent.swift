import AppIntents

struct AddDrinkIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "한 잔"
    static var handler: (@MainActor () -> Void)?
    @MainActor func perform() async throws -> some IntentResult {
        Self.handler?()
        return .result()
    }
}
