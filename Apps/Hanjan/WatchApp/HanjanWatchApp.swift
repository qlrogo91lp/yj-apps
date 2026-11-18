import ConnectivityCore
import SwiftUI

@main struct HanjanWatchApp: App {
    @StateObject private var store: WatchSessionStore
    init() {
        let connectivity = ConnectivityService()
        let sessionStore = WatchSessionStore(connectivity: connectivity)
        #if DEBUG
            if let demo = DemoLaunch.state() {
                sessionStore.end()
                sessionStore.receive(ConfigMessage(kinds: DrinkPresets.all, limit: 8))
                sessionStore.start()
                sessionStore.selectKind(DrinkPresets.soju.id)
                for _ in 0 ..< (demo == .over ? 9 : 2) {
                    sessionStore.tapMain()
                }
                if demo != .over {
                    sessionStore.selectKind(DrinkPresets.beer.id)
                    sessionStore.tapMain()
                    sessionStore.selectKind(DrinkPresets.soju.id)
                }
                if demo == .toast3 { sessionStore.cycleToast(); sessionStore.cycleToast() }
            }
        #endif
        _store = StateObject(wrappedValue: sessionStore)
    }

    var body: some Scene {
        WindowGroup { SessionView(store: store).preferredColorScheme(.dark) }
    }
}
