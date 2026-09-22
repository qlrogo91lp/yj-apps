import Combine
import Foundation
import SwiftData

/// 포그라운드 진입과 당겨서 새로고침이 부르는 단 하나의 진입점.
///
/// **쓰기는 `ModelContext` 를 직접 만진다** — `PersistenceService.upsert` 는 건당
/// `save()` 라 첫 동기화 수백 건에 맞지 않는다 (스펙 6절).
@MainActor
final class WorkoutSyncCoordinator: ObservableObject {
    @Published private(set) var isSyncing = false

    private let importer: HealthKitWorkoutImporter
    private let anchors: WorkoutQueryAnchorStore
    private let context: ModelContext

    init(importer: HealthKitWorkoutImporter = HealthKitWorkoutImporter(),
         anchors: WorkoutQueryAnchorStore = WorkoutQueryAnchorStore(),
         context: ModelContext)
    {
        self.importer = importer
        self.anchors = anchors
        self.context = context
    }

    /// **동시에 두 번 돌지 않는다.** 앵커가 경합하면 같은 워크아웃이 두 배치에 나뉘어 들어온다.
    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        await importer.requestAuthorization()
        let batch = await importer.fetch(since: anchors.load())

        do {
            let inserts = try WorkoutImportPlanner.inserts(from: batch.workouts,
                                                           existing: existingUUIDs())
            try apply(inserts)
            // **적용이 끝난 뒤에 앵커를 옮긴다.** 먼저 저장하면 실패한 배치를 영영 다시 못 읽는다.
            if let anchor = batch.anchor { anchors.save(anchor) }
        } catch {
            // 사용자에게 알리는 경로는 03b 기록 목록에서 붙인다 — iOSApp.save(_:) 와 같은 자리다.
            print("[HaruchiFit] HealthKit 동기화 실패 — \(error)")
        }
    }

    /// 이미 가진 키들. **이 집합에 있는 워크아웃은 import 가 건드리지 않는다** (스펙 3절).
    private func existingUUIDs() throws -> Set<UUID> {
        let descriptor = FetchDescriptor<WorkoutRecord>(
            predicate: #Predicate { $0.healthKitUUID != nil }
        )
        return try Set(context.fetch(descriptor).compactMap(\.healthKitUUID))
    }

    /// **한 번만 `save()` 한다** — `PersistenceService.upsert` 는 건당 save 라 첫 동기화
    /// 수백 건에 맞지 않는다 (스펙 6절).
    private func apply(_ inserts: [ImportedWorkout]) throws {
        guard !inserts.isEmpty else { return }
        for workout in inserts {
            context.insert(WorkoutRecord.make(from: workout))
        }
        try context.save()
    }
}
