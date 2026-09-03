import SwiftUI

@main
struct HaruchiFitWatchApp: App {
    @StateObject private var viewModel = WorkoutViewModel()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(viewModel)
                .task { _ = await viewModel.requestAuthorization() }
        }
    }
}
