import Combine
import ConnectivityCore
import PersistenceCore
import SwiftData
import SwiftUI

@main
struct HaruchiFitApp: App {
    /// CloudKit 엔타이틀먼트가 아직 없다 — 팩토리가 조용히 로컬로 폴백한다 (PersistenceCore README).
    private let container = PersistenceContainerFactory.make(for: [WorkoutRecord.self, Segment.self])
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var connectivity: HaruchiFitConnectivity
    @StateObject private var sync: WorkoutSyncCoordinator
    @StateObject private var alerts: AppAlertCenter
    private let context: ModelContext
    private let store: PersistenceService<WorkoutRecord>

    init() {
        // 서비스는 프로세스당 하나. 래퍼가 init 안에서 onReceive 등록까지 마치므로
        // 콜드런치 때 먼저 도착한 배달을 놓치지 않는다 (YJKit README).
        let wrapper = HaruchiFitConnectivity(service: ConnectivityService())
        _connectivity = StateObject(wrappedValue: wrapper)
        // 워치 기록 저장과 import 삽입이 같은 컨텍스트를 본다. 둘로 나누면
        // 서로의 변경을 못 보고 rollback 이 간섭할 수 있다 (PersistenceService — 단일 컨텍스트).
        let context = container.mainContext
        self.context = context
        store = PersistenceService<WorkoutRecord>(context: context)
        let alerts = AppAlertCenter()
        _alerts = StateObject(wrappedValue: alerts)
        _sync = StateObject(wrappedValue: WorkoutSyncCoordinator(context: context, alerts: alerts))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .modelContainer(container)
                .environmentObject(sync)
                .environmentObject(alerts)
                .onReceive(connectivity.$receivedRecord.compactMap(\.self)) { save($0) }
                .onChange(of: scenePhase, initial: true) { _, phase in
                    // onChange 는 기본으로 초기값을 넘기지 않는다. 콜드 런치도 포그라운드 진입이다.
                    guard phase == .active else { return }
                    Task { await sync.sync() }
                }
        }
    }

    /// 워치가 보낸 기록을 저장한다.
    ///
    /// CloudKit 이 `.unique` 를 막으므로 **중복 방지는 여기 책임이다** (아키텍처 3절).
    /// `healthKitUUID` 가 있으면 그 키로 기존 기록을 갈아끼우되 부위·메모는 넘겨받고, 없으면 그냥 추가한다 —
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
                let replacing = #Predicate<WorkoutRecord> { $0.healthKitUUID == uuid }
                // 재전송이면 사용자 편집값과 영속 ID를 지킨 채 운동 데이터만 갱신한다.
                // 열린 상세 시트가 이 객체를 잡고 있으므로 지우고 새로 넣으면 안 된다.
                if let existing = try store.fetch(matching: replacing).first {
                    existing.updateWorkoutData(from: message, in: context)
                    try context.save()
                } else {
                    try store.upsert(record, replacing: replacing)
                }
            } else {
                try store.upsert(record)
            }
        } catch {
            context.rollback()
            print("[HaruchiFit] 워크아웃 저장 실패 — \(error)")
            alerts.report(.saveFailed)
        }
    }
}
