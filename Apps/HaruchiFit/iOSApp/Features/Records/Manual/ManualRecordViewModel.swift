import Combine
import Foundation

@MainActor
final class ManualRecordViewModel: ObservableObject {
    @Published var draft: ManualRecordDraft
    let record: WorkoutRecord?

    init(record: WorkoutRecord?, initialMemoDraft: String? = nil) {
        self.record = record
        if let record {
            draft = ManualRecordDraft(startedAt: record.startedAt,
                                      durationMinutes: record.totalSeconds / 60,
                                      kind: record.orderedSegments.first?.kind ?? .strength,
                                      bodyParts: Set(record.bodyParts),
                                      memo: initialMemoDraft ?? record.memo ?? "")
        } else {
            draft = ManualRecordDraft()
        }
    }

    func toggle(_ part: BodyPart) {
        if draft.bodyParts.contains(part) {
            draft.bodyParts.remove(part)
        } else {
            draft.bodyParts.insert(part)
        }
    }

    func save(using store: ManualRecordStore) throws {
        try store.save(draft, editing: record)
    }
}
