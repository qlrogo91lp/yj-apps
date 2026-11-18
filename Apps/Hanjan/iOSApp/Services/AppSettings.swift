import Combine
import Foundation

@MainActor final class AppSettings: ObservableObject {
    private let defaults: UserDefaults
    @Published var limit: Double {
        didSet { if !limit.isFinite || limit < 1 { limit = 1 }; defaults.set(limit, forKey: "limit") }
    }

    @Published var hasOnboarded: Bool {
        didSet { defaults.set(hasOnboarded, forKey: "hasOnboarded") }
    }

    @Published var alertsEnabled: Bool {
        didSet { defaults.set(alertsEnabled, forKey: "alertsEnabled") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.object(forKey: "limit") as? Double ?? 8
        limit = stored.isFinite ? max(1, stored) : 8
        hasOnboarded = defaults.bool(forKey: "hasOnboarded")
        alertsEnabled = defaults.object(forKey: "alertsEnabled") as? Bool ?? true
    }
}
