import Combine
import Foundation

@MainActor
final class MatchContainerViewModel: ObservableObject {
    @Published var watchConnected: Bool = false
    @Published var metrics: WorkoutMetrics = WorkoutMetrics()

    private var cancellables = Set<AnyCancellable>()

    init() {
        let service = WatchConnectivityService.shared

        service.$isWatchReachable
            .receive(on: DispatchQueue.main)
            .assign(to: &$watchConnected)

        service.$receivedMetrics
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .assign(to: &$metrics)
    }
}
