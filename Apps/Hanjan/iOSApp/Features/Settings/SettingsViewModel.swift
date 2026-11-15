import Combine
import Foundation
import SwiftData

/// 설정의 한도 규칙과 술 목록 추가·편집·삭제. 한도 값 자체는 호출부(T9 의 `AppSettings`)가 갖는다.
final class SettingsViewModel: ObservableObject {
    static let limitRange = 1.0 ... 30.0
    static let limitStep = 0.5
    static let defaultLimit = 8.0

    @Published private(set) var kinds: [DrinkKind] = []
    private var context: ModelContext?

    /// 한도는 1~30, 0.5 단위. 숫자가 아니면 기본 8.
    static func clampLimit(_ value: Double) -> Double {
        guard value.isFinite else { return defaultLimit }
        let stepped = (value / limitStep).rounded() * limitStep
        return min(max(stepped, limitRange.lowerBound), limitRange.upperBound)
    }

    /// 편집 화면의 "소주 약 N잔" 미리보기. 잘못된 입력이어도 NaN 대신 "0".
    static func sojuPreview(abv: Double, volumeML: Double) -> String {
        let kind = DrinkKind(id: UUID(), name: "", abv: abv, volumeML: volumeML, isPreset: false, sortOrder: 0)
        return SojuFormat.string(kind.alcoholGrams / DrinkPresets.soju.alcoholGrams)
    }

    func configure(context: ModelContext) {
        guard self.context == nil else { return }
        self.context = context
        reload()
    }

    func reload() {
        guard let context else { return }
        let records = (try? context.fetch(FetchDescriptor<DrinkKindRecord>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        kinds = records.map {
            DrinkKind(id: $0.id, name: $0.name, abv: $0.abv, volumeML: $0.volumeML, isPreset: $0.isPreset, sortOrder: $0.sortOrder)
        }
    }

    /// `id` 가 nil 이면 새 술을 맨 뒤에 추가하고, 있으면 그 술을 고친다. 프리셋은 고쳐도 프리셋으로 남는다.
    @discardableResult
    func save(id: UUID?, name: String, abv: Double, volumeML: Double) -> Result<Void, KindValidationError> {
        let validation = KindValidation.validate(name: name, abv: abv, volumeML: volumeML)
        guard case .success = validation, let context else { return validation }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let id, let record = record(id: id) {
            record.name = trimmed
            record.abv = abv
            record.volumeML = volumeML
        } else {
            let nextOrder = (kinds.map(\.sortOrder).max() ?? -1) + 1
            context.insert(DrinkKindRecord(name: trimmed, abv: abv, volumeML: volumeML, isPreset: false, sortOrder: nextOrder))
        }
        try? context.save()
        reload()
        return .success(())
    }

    /// 사용자가 추가한 술만 지운다. 프리셋이면 false. 이미 남은 기록의 잔은 이름·알코올량을 따로 갖고 있어 영향이 없다.
    @discardableResult
    func delete(id: UUID) -> Bool {
        guard let context, let record = record(id: id), !record.isPreset else { return false }
        context.delete(record)
        try? context.save()
        reload()
        return true
    }

    private func record(id: UUID) -> DrinkKindRecord? {
        var descriptor = FetchDescriptor<DrinkKindRecord>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? context?.fetch(descriptor))?.first
    }
}
