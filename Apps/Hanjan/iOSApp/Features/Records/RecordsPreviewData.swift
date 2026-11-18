import Foundation
import SwiftData

/// 기록 화면 프리뷰용 인메모리 컨테이너. 지난 술자리 몇 개와 술 목록을 채운다.
enum RecordsPreviewData {
    static func container() -> ModelContainer {
        let schema = Schema(HanjanSchema.models)
        let container: ModelContainer
        do {
            container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        } catch {
            fatalError("프리뷰 컨테이너를 만들 수 없다: \(error)")
        }
        let context = container.mainContext
        for kind in DrinkPresets.all {
            context.insert(DrinkKindRecord(
                id: kind.id,
                name: kind.name,
                abv: kind.abv,
                volumeML: kind.volumeML,
                isPreset: true,
                sortOrder: kind.sortOrder
            ))
        }
        let friends = [CompanionRecord(name: "지민"), CompanionRecord(name: "민수"), CompanionRecord(name: "동료들")]
        friends.forEach(context.insert)

        let now = Date()
        let recent = insert(context, start: now.addingTimeInterval(-86400 * 1.2), drinks: [(.soju, 3), (.beer, 2)], toasts: 8)
        recent.placeName = "성수동"
        recent.companions = Array(friends.prefix(2))
        recent.condition = 2
        recent.memo = "오랜만에 만나서 즐거웠다."
        let exceeded = insert(context, start: now.addingTimeInterval(-86400 * 5), drinks: [(.soju, 9)], toasts: 0)
        exceeded.placeName = "을지로"
        exceeded.condition = 4
        let noPlace = insert(context, start: now.addingTimeInterval(-86400 * 20), drinks: [(.somaek, 3)], toasts: 0)
        noPlace.latitude = nil
        noPlace.longitude = nil
        noPlace.companions = [friends[2]]
        try? context.save()
        return container
    }

    /// 첫 번째 프리뷰 세션 id. 상세·편집·회고 프리뷰가 쓴다.
    static func firstSessionId(in container: ModelContainer) -> UUID {
        let descriptor = FetchDescriptor<SessionRecord>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        return (try? container.mainContext.fetch(descriptor))?.first?.id ?? UUID()
    }

    private enum Preset {
        case soju, beer, somaek

        var kind: DrinkKind {
            switch self {
            case .soju: DrinkPresets.soju
            case .beer: DrinkPresets.beer
            case .somaek: DrinkPresets.somaek
            }
        }
    }

    @discardableResult
    private static func insert(_ context: ModelContext, start: Date, drinks: [(Preset, Int)], toasts: Int) -> SessionRecord {
        let record = SessionRecord(startedAt: start, endedAt: start.addingTimeInterval(3 * 3600), limit: 8)
        record.latitude = 37.5445
        record.longitude = 127.0557
        context.insert(record)
        var minute: TimeInterval = 0
        var grams: Double = 0
        for (preset, count) in drinks {
            for _ in 0 ..< count {
                minute += 10
                grams += preset.kind.alcoholGrams
                context.insert(EntryRecord(
                    kindId: preset.kind.id,
                    kindName: preset.kind.name,
                    alcoholGrams: preset.kind.alcoholGrams,
                    loggedAt: start.addingTimeInterval(minute * 60),
                    session: record
                ))
            }
        }
        for _ in 0 ..< toasts {
            minute += 5
            context.insert(EntryRecord(
                kindId: DrinkPresets.soju.id,
                kindName: DrinkPresets.soju.name,
                loggedAt: start.addingTimeInterval(minute * 60),
                isToastOnly: true,
                session: record
            ))
        }
        record.totalGrams = grams
        record.toastOnlyCount = toasts
        return record
    }
}
