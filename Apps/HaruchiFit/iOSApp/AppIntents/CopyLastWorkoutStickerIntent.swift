import AppIntents
import SwiftData

struct CopyLastWorkoutStickerIntent: AppIntent {
    static let title: LocalizedStringResource = "Copy Last Workout Sticker"
    static let description = IntentDescription("Copy the most recent workout as a sticker.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let context = ModelContext(HaruchiFitApp.modelContainer)
            let records = try context.fetch(FetchDescriptor<WorkoutRecord>())
            guard let record = RecordShareBuilder.latestRecord(in: records) else {
                return .result(dialog: "No saved workouts found.")
            }
            guard record.totalSeconds > 0, record.activeCalories != nil,
                  RecordShareButton.copySticker(content: RecordShareBuilder.content(for: record))
            else {
                return .result(dialog: "Couldn't copy the last workout sticker.")
            }
            let date = record.effectiveEndedAt.formatted(date: .long, time: .shortened)
            return .result(dialog: "Copied the workout that ended at \(date) as a sticker.")
        } catch {
            return .result(dialog: "Couldn't copy the last workout sticker.")
        }
    }
}
