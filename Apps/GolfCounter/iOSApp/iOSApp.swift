import PersistenceCore
import SwiftData
import SwiftUI

@main
struct GolfCounterApp: App {
    private let container = PersistenceContainerFactory.make(for: [GolfRound.self])

    var body: some Scene {
        WindowGroup {
            Text("GolfCounter")
        }
        .modelContainer(container)
    }
}
