import Combine
import ConnectivityCore
import PersistenceCore
import SwiftData
import SwiftUI

@main
struct HaruchiFitApp: App {
    /// CloudKit 엔타이틀먼트가 아직 없다 — 팩토리가 조용히 로컬로 폴백한다 (PersistenceCore README).
    private let container = PersistenceContainerFactory.make(for: [WorkoutRecord.self, Segment.self])
    @StateObject private var connectivity: HaruchiFitConnectivity
    private let store: PersistenceService<WorkoutRecord>

    init() {
        // 서비스는 프로세스당 하나. 래퍼가 init 안에서 onReceive 등록까지 마치므로
        // 콜드런치 때 먼저 도착한 배달을 놓치지 않는다 (YJKit README).
        let wrapper = HaruchiFitConnectivity(service: ConnectivityService())
        _connectivity = StateObject(wrappedValue: wrapper)
        store = PersistenceService<WorkoutRecord>(context: ModelContext(container))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
                .onReceive(connectivity.$receivedRecord.compactMap(\.self)) { save($0) }
        }
    }

    /// 워치가 보낸 기록을 저장한다.
    ///
    /// CloudKit 이 `.unique` 를 막으므로 **중복 방지는 여기 책임이다** (아키텍처 3절).
    /// `healthKitUUID` 가 있으면 그 키로 기존 기록을 갈아끼우고, 없으면 그냥 추가한다 —
    /// 키가 없는 기록끼리는 구분할 방법이 없어 중복 검사를 걸 수 없다.
    private func save(_ message: WorkoutRecordMessage) {
        let record = WorkoutRecord(healthKitUUID: message.healthKitUUID,
                                   startedAt: message.startedAt,
                                   endedAt: message.endedAt,
                                   totalSeconds: message.totalSeconds,
                                   activeCalories: message.activeCalories,
                                   totalCalories: message.totalCalories,
                                   averageHeartRate: message.averageHeartRate,
                                   source: .watch)
        record.segments = message.segments.map {
            Segment(kind: $0.kind, startOffset: $0.startOffset, durationSeconds: $0.durationSeconds)
        }

        do {
            if let uuid = message.healthKitUUID {
                try store.upsert(record, replacing: #Predicate { $0.healthKitUUID == uuid })
            } else {
                try store.upsert(record)
            }
        } catch {
            // 저장 실패를 사용자에게 알리는 경로는 기록 탭 플랜에서 붙인다.
            print("[HaruchiFit] 워크아웃 저장 실패 — \(error)")
        }
    }
}
