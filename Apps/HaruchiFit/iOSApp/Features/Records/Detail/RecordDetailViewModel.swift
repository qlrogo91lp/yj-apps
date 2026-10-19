import Combine
import Foundation
import SwiftData

@MainActor
final class RecordDetailViewModel: ObservableObject {
    let summary: RecordDetailSummary
    let shareContent: RecordShareContent
    @Published private(set) var bodyParts: [BodyPart]
    @Published var memoDraft: String
    /// 메모를 실제로 저장할 때마다 1씩 오른다. 화면은 이 값의 변화를 보고 `저장됨` 표시를 띄운다.
    @Published private(set) var memoSaveCount = 0
    let isManual: Bool
    private let record: WorkoutRecord
    private let context: ModelContext

    init(record: WorkoutRecord,
         context: ModelContext,
         initialMemoDraft: String? = nil,
         calendar: Calendar = .current)
    {
        self.record = record
        isManual = record.source == .manual
        self.context = context
        summary = RecordDetailBuilder.summary(for: record, now: Date(), calendar: calendar)
        shareContent = RecordShareBuilder.content(for: record)
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
        let saved = persist(normalizeMemoDraft: true)
        if saved { memoSaveCount += 1 }
        return saved
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
