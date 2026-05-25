import Foundation

class ModeViewModel: ObservableObject {
    @Published var selectedMode: MatchFormat {
        didSet { UserDefaults.standard.set(selectedMode.rawValue, forKey: "lastSelectedMode") }
    }
    @Published var noAdRule: Bool {
        didSet { UserDefaults.standard.set(noAdRule, forKey: "lastNoAdRule") }
    }
    @Published var noTieRule: Bool {
        didSet { UserDefaults.standard.set(noTieRule, forKey: "lastNoTieRule") }
    }
    @Published var gameThreshold: Int {
        didSet { UserDefaults.standard.set(gameThreshold, forKey: "lastGameThreshold") }
    }

    var options: MatchOptions {
        MatchOptions(mode: selectedMode, noAdRule: noAdRule, noTieRule: noTieRule, gameThreshold: gameThreshold)
    }

    init() {
        let ud = UserDefaults.standard
        selectedMode  = MatchFormat(rawValue: ud.string(forKey: "lastSelectedMode") ?? "") ?? .oneSet
        noAdRule      = ud.object(forKey: "lastNoAdRule") as? Bool ?? true
        noTieRule     = ud.object(forKey: "lastNoTieRule") as? Bool ?? true
        gameThreshold = ud.object(forKey: "lastGameThreshold") as? Int ?? 6
    }
}
