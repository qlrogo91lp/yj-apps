import Foundation

class ModeViewModel: ObservableObject {
    @Published var noAdRule: Bool = true
    @Published var noTieRule: Bool = false

    func options(for format: MatchFormat) -> MatchOptions {
        let mode = MatchMode(rawValue: format.rawValue) ?? .oneSet
        return MatchOptions(mode: mode, noAdRule: noAdRule, noTieRule: noTieRule)
    }
}
