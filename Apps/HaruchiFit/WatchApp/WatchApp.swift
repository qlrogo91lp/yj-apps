import ConnectivityCore
import SwiftUI

@main
struct HaruchiFitWatchApp: App {
    /// **프로세스당 정확히 하나만 만든다** — 두 번째 인스턴스가 WCSession delegate 를 빼앗아
    /// 첫 인스턴스의 수신이 조용히 죽는다 (YJKit README).
    @StateObject private var viewModel = WorkoutViewModel(connectivity: ConnectivityService())

    var body: some Scene {
        WindowGroup {
            WorkoutRootView()
                .environmentObject(viewModel)
                .task { _ = await viewModel.requestAuthorization() }
        }
    }
}
