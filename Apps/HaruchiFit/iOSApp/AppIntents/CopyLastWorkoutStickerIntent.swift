import AppIntents
import SwiftData

struct CopyLastWorkoutStickerIntent: AppIntent {
    static let title: LocalizedStringResource = "shortcut_copy_sticker_title"
    static let description = IntentDescription("shortcut_copy_sticker_description")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let context = ModelContext(HaruchiFitApp.modelContainer)
            let records = try context.fetch(FetchDescriptor<WorkoutRecord>())
            guard let record = RecordShareBuilder.latestRecord(in: records) else {
                return .result(dialog: "shortcut_copy_sticker_empty")
            }
            guard record.totalSeconds > 0, record.activeCalories != nil,
                  RecordShareButton.copySticker(content: RecordShareBuilder.content(for: record))
            else {
                return .result(dialog: "shortcut_copy_sticker_failed")
            }
            let date = record.effectiveEndedAt.formatted(date: .long, time: .shortened)
            return .result(dialog: "shortcut_copy_sticker_done \(date)")
        } catch {
            return .result(dialog: "shortcut_copy_sticker_failed")
        }
    }
}
