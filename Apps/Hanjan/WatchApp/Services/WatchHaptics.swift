import WatchKit

@MainActor final class WatchHaptics {
    func click() {
        WKInterfaceDevice.current().play(.click)
    }

    func alert(_ level: LimitLevel) {
        if level == .warning { WKInterfaceDevice.current().play(.notification) }
        if level == .reached { WKInterfaceDevice.current().play(.failure) }
    }
}
