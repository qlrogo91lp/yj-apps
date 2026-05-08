import Foundation

class ModeViewModel: ObservableObject {
    @Published var selectedMode: MatchMode = .oneSet
    @Published var noAdRule: Bool = true
    @Published var noTieRule: Bool = false

    var options: MatchOptions {
        MatchOptions(mode: selectedMode, noAdRule: noAdRule, noTieRule: noTieRule)
    }
}
