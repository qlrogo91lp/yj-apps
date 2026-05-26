import Foundation

enum HistoryViewMode {
    case list
    case calendar
}

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var viewMode: HistoryViewMode = .list

    func toggleViewMode() {
        viewMode = viewMode == .list ? .calendar : .list
    }

}
