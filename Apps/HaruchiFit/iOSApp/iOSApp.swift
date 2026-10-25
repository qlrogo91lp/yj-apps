import ConnectivityCore
import PersistenceCore
import SwiftData
import SwiftUI

@main
struct HaruchiFitApp: App {
    /// CloudKit 엔타이틀먼트가 아직 없다 — 팩토리가 조용히 로컬로 폴백한다 (PersistenceCore README).
    private let container = PersistenceContainerFactory.make(for: [WorkoutRecord.self, Segment.self])
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("onboardingSeenVersion") private var onboardingSeenVersion = 0
    @StateObject private var sync: WorkoutSyncCoordinator
    @StateObject private var alerts: AppAlertCenter
    private let connectivity: HaruchiFitConnectivity

    init() {
        // 워치 기록 저장과 import 삽입이 같은 컨텍스트를 본다. 둘로 나누면
        // 서로의 변경을 못 보고 rollback 이 간섭할 수 있다 (PersistenceService — 단일 컨텍스트).
        let context = container.mainContext
        let alerts = AppAlertCenter()
        _alerts = StateObject(wrappedValue: alerts)
        _sync = StateObject(wrappedValue: WorkoutSyncCoordinator(context: context, alerts: alerts))
        // 서비스는 프로세스당 하나. 래퍼가 init 안에서 onReceive 등록까지 마치므로
        // 콜드런치 때 먼저 도착한 배달을 놓치지 않는다 (YJKit README).
        // 저장은 받는 즉시 여기서 한다 — 화면이 없는 백그라운드 실행에서도 돈다.
        connectivity = HaruchiFitConnectivity(service: ConnectivityService()) { message in
            do {
                try context.saveWatchRecord(message)
            } catch {
                context.rollback()
                print("[HaruchiFit] 워크아웃 저장 실패 — \(error)")
                alerts.report(.saveFailed)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showsOnboarding {
                    OnboardingView(onFinished: finishOnboarding)
                } else {
                    ContentView()
                }
            }
            .preferredColorScheme(.dark)
            .modelContainer(container)
            .environmentObject(sync)
            .environmentObject(alerts)
            .onChange(of: scenePhase, initial: true) { _, phase in
                // onChange 는 기본으로 초기값을 넘기지 않는다. 콜드 런치도 포그라운드 진입이다.
                // 온보딩을 마치기 전에는 동기화를 돌리지 않는다 — 동기화가 건강 권한을 요청하기 때문이다.
                guard phase == .active, !showsOnboarding else { return }
                Task { await sync.sync() }
            }
        }
    }

    private var showsOnboarding: Bool {
        OnboardingGate.shouldShow(seenVersion: onboardingSeenVersion)
    }

    /// 본 버전을 먼저 남기고 첫 동기화를 돌린다 — 권한 시트가 뜬 채 앱이 꺼져도 다시 온보딩이 뜨지 않는다.
    private func finishOnboarding() {
        onboardingSeenVersion = OnboardingGate.version
        Task { await sync.sync() }
    }
}
