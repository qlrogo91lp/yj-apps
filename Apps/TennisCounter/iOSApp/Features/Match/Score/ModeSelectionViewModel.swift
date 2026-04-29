import SwiftUI

@MainActor
final class ModeSelectionViewModel: ObservableObject {
    @Published var selectedFormat: MatchFormat?

    func selectFormat(_ format: MatchFormat) {
        selectedFormat = format
    }
}
