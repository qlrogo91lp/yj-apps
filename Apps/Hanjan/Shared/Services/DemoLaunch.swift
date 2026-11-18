#if DEBUG
    import Foundation

    nonisolated enum DemoLaunch: String {
        case basic, toast3, over

        static func state(arguments: [String] = ProcessInfo.processInfo.arguments) -> Self? {
            guard let index = arguments.firstIndex(of: "-HanjanDemo"), arguments.indices.contains(index + 1) else { return nil }
            return Self(rawValue: arguments[index + 1])
        }
    }
#endif
