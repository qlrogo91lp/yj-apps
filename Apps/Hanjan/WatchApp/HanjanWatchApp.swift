import ConnectivityCore
import SwiftUI

@main struct HanjanWatchApp: App {
    @StateObject private var store: WatchSessionStore
    init() {
        let connectivity = ConnectivityService()
        _store = StateObject(wrappedValue: WatchSessionStore(connectivity: connectivity))
    }

    var body: some Scene {
        WindowGroup { SessionView(store: store).preferredColorScheme(.dark) }
    }
}
