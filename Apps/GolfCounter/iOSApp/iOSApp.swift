import PersistenceCore
import SwiftData
import SwiftUI

@main
struct GolfCounterApp: App {
    private let container: ModelContainer
    /// 참조를 잡아 두기만 하면 된다 — 살아 있는 동안 WCSession 수신 등록이 유지된다.
    private let receiver: RoundReceiveService

    init() {
        let container = PersistenceContainerFactory.make(for: [GolfRound.self])
        self.container = container
        // App.init은 main에서 돌지만 Swift 5 모드에서는 그 사실이 타입에 드러나지 않는다.
        // 수신 등록은 콜드런치 컨텍스트를 놓치지 않도록 여기서 즉시 끝내야 한다 (RoundReceiveService 주석).
        receiver = MainActor.assumeIsolated {
            RoundReceiveService(context: ModelContext(container))
        }
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(container)
    }
}
