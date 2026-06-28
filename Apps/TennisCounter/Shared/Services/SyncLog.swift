import OSLog

enum SyncLog {
    private static let logger = Logger(subsystem: "com.yj.TennisCounter.sync", category: "score")

    static func sent(_ message: String) {
        logger.notice("SENT \(message, privacy: .public)")
    }

    static func recv(_ message: String) {
        logger.notice("RECV \(message, privacy: .public)")
    }
}
