import Foundation
@testable import Hanjan
import SwiftData
import Testing

@MainActor
struct SettingsViewModelTests {
    private let container: ModelContainer
    private let viewModel = SettingsViewModel()

    init() throws {
        let schema = Schema(HanjanSchema.models)
        container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        for kind in [DrinkPresets.soju, DrinkPresets.beer] {
            container.mainContext.insert(DrinkKindRecord(
                id: kind.id, name: kind.name, abv: kind.abv, volumeML: kind.volumeML, isPreset: true, sortOrder: kind.sortOrder
            ))
        }
        try container.mainContext.save()
        viewModel.configure(context: container.mainContext)
    }

    @Test func clampLimit_staysInRangeOnHalfSteps() {
        #expect(SettingsViewModel.clampLimit(0) == 1)
        #expect(SettingsViewModel.clampLimit(-5) == 1)
        #expect(SettingsViewModel.clampLimit(31) == 30)
        #expect(SettingsViewModel.clampLimit(7.3) == 7.5)
        #expect(SettingsViewModel.clampLimit(7.2) == 7)
        #expect(SettingsViewModel.clampLimit(.nan) == 8)
    }

    @Test func sojuPreview_neverNaN() {
        #expect(SettingsViewModel.sojuPreview(abv: 16, volumeML: 50) == "1")
        #expect(SettingsViewModel.sojuPreview(abv: 0, volumeML: 50) == "0")
        #expect(SettingsViewModel.sojuPreview(abv: 16, volumeML: 0) == "0")
        #expect(SettingsViewModel.sojuPreview(abv: .nan, volumeML: 50) == "0")
        #expect(SettingsViewModel.sojuPreview(abv: 40, volumeML: 30) == "1.5")
    }

    @Test func configure_loadsKindsInOrder() {
        #expect(viewModel.kinds.map(\.name) == ["소주", "맥주"])
    }

    @Test func saveNew_appendsUserKindAtEnd() {
        let result = viewModel.save(id: nil, name: " 하이볼 ", abv: 7, volumeML: 200)
        #expect((try? result.get()) != nil)
        #expect(viewModel.kinds.map(\.name) == ["소주", "맥주", "하이볼"])
        #expect(viewModel.kinds.last?.isPreset == false)
        #expect(viewModel.kinds.last?.sortOrder == 2)
    }

    @Test func saveInvalid_doesNotInsert() throws {
        let result = viewModel.save(id: nil, name: "하이볼", abv: 0, volumeML: 200)
        if case let .failure(error) = result { #expect(error == .abvOutOfRange) } else { Issue.record("저장되면 안 된다") }
        #expect(try container.mainContext.fetch(FetchDescriptor<DrinkKindRecord>()).count == 2)
    }

    @Test func editPreset_keepsIdAndPresetFlag() {
        _ = viewModel.save(id: DrinkPresets.soju.id, name: "참이슬", abv: 16.5, volumeML: 50)
        let soju = viewModel.kinds.first { $0.id == DrinkPresets.soju.id }
        #expect(soju?.name == "참이슬")
        #expect(soju?.abv == 16.5)
        #expect(soju?.isPreset == true)
        #expect(viewModel.kinds.count == 2)
    }

    @Test func deletePreset_isRefused_userKindDeleted() {
        #expect(viewModel.delete(id: DrinkPresets.soju.id) == false)
        #expect(viewModel.kinds.count == 2)
        _ = viewModel.save(id: nil, name: "하이볼", abv: 7, volumeML: 200)
        let highball = viewModel.kinds.last?.id ?? UUID()
        #expect(viewModel.delete(id: highball) == true)
        #expect(viewModel.kinds.map(\.name) == ["소주", "맥주"])
    }
}
