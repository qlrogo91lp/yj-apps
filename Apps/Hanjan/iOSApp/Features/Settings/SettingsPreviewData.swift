#if DEBUG
    import Foundation
    import SwiftData

    /// 설정 화면 프리뷰용 인메모리 컨테이너. 프리셋 + 사용자 술 하나.
    enum SettingsPreviewData {
        static func container() -> ModelContainer {
            let schema = Schema(HanjanSchema.models)
            let container: ModelContainer
            do {
                container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
            } catch {
                fatalError("프리뷰 컨테이너를 만들 수 없다: \(error)")
            }
            for kind in DrinkPresets.all {
                container.mainContext.insert(DrinkKindRecord(
                    id: kind.id, name: kind.name, abv: kind.abv, volumeML: kind.volumeML, isPreset: true, sortOrder: kind.sortOrder
                ))
            }
            container.mainContext.insert(DrinkKindRecord(name: "하이볼", abv: 7, volumeML: 200, isPreset: false, sortOrder: DrinkPresets.all.count))
            try? container.mainContext.save()
            return container
        }
    }
#endif
