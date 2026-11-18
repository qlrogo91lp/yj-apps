import AppIntents
import SwiftData

struct CopyLastWorkoutStickerIntent: AppIntent {
    static let title: LocalizedStringResource = "shortcut_copy_sticker_title"
    static let description = IntentDescription("shortcut_copy_sticker_description")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let service = SessionPersistenceService()
            service.configure(with: ModelContext(TennisCounterApp.modelContainer))
            guard let record = try service.fetchLatestEnded() else {
                return .result(dialog: "shortcut_copy_sticker_empty")
            }
            guard let share = SessionShareData(record: record), SessionShareButton.copySticker(share),
                  let endedAt = record.endedAt
            else {
                return .result(dialog: "shortcut_copy_sticker_failed")
            }
            let date = endedAt.formatted(date: .long, time: .shortened)
            return .result(dialog: "shortcut_copy_sticker_done \(date)")
        } catch {
            return .result(dialog: "shortcut_copy_sticker_failed")
        }
    }
}
