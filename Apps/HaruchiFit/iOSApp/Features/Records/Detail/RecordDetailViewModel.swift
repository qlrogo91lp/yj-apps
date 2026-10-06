import Combine
import Foundation
import SwiftData

@MainActor
final class RecordDetailViewModel: ObservableObject {
    let summary: RecordDetailSummary
    @Published private(set) var bodyParts: [BodyPart]
    @Published var memoDraft: String
    private let record: WorkoutRecord
    private let context: ModelContext

    init(record: WorkoutRecord,
         context: ModelContext,
         initialMemoDraft: String? = nil,
         calendar: Calendar = .current)
    {
        self.record = record
        self.context = context
        summary = RecordDetailBuilder.summary(for: record, now: Date(), calendar: calendar)
        bodyParts = record.bodyParts
        memoDraft = initialMemoDraft ?? record.memo ?? ""
    }

    func toggle(_ part: BodyPart) -> Bool {
        record.toggle(part)
        return persist(normalizeMemoDraft: false)
    }

    func commitMemo() -> Bool {
        let before = record.memo
        record.setMemo(memoDraft)
        guard record.memo != before else { memoDraft = record.memo ?? ""; return true }
        return persist(normalizeMemoDraft: true)
    }

    private func persist(normalizeMemoDraft: Bool) -> Bool {
        defer { bodyParts = record.bodyParts }
        do {
            try context.save()
            if normalizeMemoDraft { memoDraft = record.memo ?? "" }
            return true
        } catch {
            context.rollback()
            print("[HaruchiFit] 기록 편집 저장 실패 — \(error)")
            return false
        }
    }
}
