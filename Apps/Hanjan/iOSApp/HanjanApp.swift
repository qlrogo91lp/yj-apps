import Combine
import ConnectivityCore
import PersistenceCore
import SwiftData
import SwiftUI
import UserNotifications

@MainActor final class AppServices: ObservableObject {
    let container: ModelContainer
    let settings: AppSettings
    let store: PhoneSessionStore
    let liveActivity = LiveActivityController()
    private let connectivity: ConnectivityService

    init() {
        container = PersistenceContainerFactory.make(for: HanjanSchema.models)
        let archive = SessionArchive(context: container.mainContext)
        do { try archive.seedPresetsIfNeeded() } catch { NSLog("프리셋 저장 실패: %@", String(describing: error)) }
        settings = AppSettings()
        connectivity = ConnectivityService()
        store = PhoneSessionStore(connectivity: connectivity, archive: archive, settings: settings)
        store.onChange = { [weak self] session in self?.sync(session) }
        AddDrinkIntent.handler = { [weak store] in store?.tapMain() }
        store.pushConfig()
        sync(store.session)
        #if DEBUG
            if let demo = DemoLaunch.state() {
                settings.hasOnboarded = true
                settings.limit = 8
                store.end()
                store.start()
                store.selectKind(DrinkPresets.soju.id)
                for _ in 0 ..< (demo == .over ? 9 : 2) {
                    store.tapMain()
                }
                if demo != .over {
                    store.selectKind(DrinkPresets.beer.id)
                    store.tapMain()
                    store.selectKind(DrinkPresets.soju.id)
                }
                if demo == .toast3 { store.cycleToast(); store.cycleToast() }
                store.pushConfig()
            }
        #endif
    }

    func sync(_ session: LiveSession?) {
        let name = store.kinds.first(where: { $0.id == session?.currentKindId })?.name ?? ""
        liveActivity.sync(session, kindName: name)
    }
}

final class NotificationDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(_: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let raw = response.notification.request.content.userInfo["sessionId"] as? String, let id = UUID(uuidString: raw) else { return }
        await MainActor.run { ReviewRouter.shared.sessionId = id }
    }
}

@MainActor final class ReviewRouter: ObservableObject {
    static let shared = ReviewRouter()
    @Published var sessionId: UUID?
}

@main struct HanjanApp: App {
    @UIApplicationDelegateAdaptor(NotificationDelegate.self) private var delegate
    @StateObject private var services = AppServices()
    var body: some Scene {
        WindowGroup {
            RootView(store: services.store, settings: services.settings, onActive: { services.sync(services.store.session) })
                .modelContainer(services.container)
                .preferredColorScheme(.dark)
        }
    }
}
