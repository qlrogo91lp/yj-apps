import AppIntents
import SwiftData

struct CopyLastWorkoutStickerIntent: AppIntent {
    static let title: LocalizedStringResource = "Copy Last Workout Sticker"
    static let description = IntentDescription("Copy the most recent workout as a sticker.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let service = SessionPersistenceService()
            service.configure(with: ModelContext(TennisCounterApp.modelContainer))
            guard let record = try service.fetchLatestEnded() else {
                return .result(dialog: "No saved workouts found.")
            }
            guard let share = SessionShareData(record: record), SessionShareButton.copySticker(share),
                  let endedAt = record.endedAt
            else {
                return .result(dialog: "Couldn't copy the last workout sticker.")
            }
            let date = endedAt.formatted(date: .long, time: .shortened)
            return .result(dialog: "Copied the workout that ended at \(date) as a sticker.")
        } catch {
            return .result(dialog: "Couldn't copy the last workout sticker.")
        }
    }
}
