import Foundation
import MonitoringCore

/// 기록된 호출을 순서대로 보관한다. YJKit `Tests/MonitoringCoreTests/CrashReportingSpy.swift` 와 같은 모양.
final class CrashReportingSpy: CrashReporting, @unchecked Sendable {
    enum Call: Equatable {
        case record(domain: String, code: Int, context: [String: String])
        case log(String)
    }

    private(set) var calls: [Call] = []

    func record(_ error: Error, context: [String: String]) {
        let ns = error as NSError
        calls.append(.record(domain: ns.domain, code: ns.code, context: context))
    }

    func log(_ message: String) {
        calls.append(.log(message))
    }
}
