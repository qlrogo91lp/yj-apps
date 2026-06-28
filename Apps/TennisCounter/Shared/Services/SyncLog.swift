import OSLog

enum SyncLog {
    private static let logger = Logger(subsystem: "com.yj.TennisCounter.sync", category: "score")
    private static let sessionLogger = Logger(subsystem: "com.yj.TennisCounter.sync", category: "session")

    static func sent(_ message: String) {
        logger.notice("SENT \(message, privacy: .public)")
    }

    static func recv(_ message: String) {
        logger.notice("RECV \(message, privacy: .public)")
    }

    static func session(_ message: String) {
        sessionLogger.notice("\(message, privacy: .public)")
    }
}
