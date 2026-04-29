import Foundation
import SwiftData

enum HistoryViewMode {
    case list
    case calendar
}

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var viewMode: HistoryViewMode = .list
    @Published var selectedMatch: Match?

    func toggleViewMode() {
        viewMode = viewMode == .list ? .calendar : .list
    }

    func wonMatch(_ match: Match) -> Bool {
        match.myTotalSets > match.yourTotalSets
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    func setScore(_ match: Match) -> String {
        "\(match.myTotalSets) - \(match.yourTotalSets)"
    }
}
