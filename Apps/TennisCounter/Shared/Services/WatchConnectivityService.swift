import Combine
import Foundation
import WatchConnectivity

// MARK: - Message Types

private enum WCMessageType: String {
    case sessionStart
    case scoreState
    case matchEnd
    case metrics
    case workoutEnd
}

struct SessionStartMessage {
    let sessionId: UUID
    let options: MatchOptions

    func toDictionary() -> [String: Any] {
        [
            "type": WCMessageType.sessionStart.rawValue,
            "sessionId": sessionId.uuidString,
            "mode": options.mode.rawValue,
            "noAdRule": options.noAdRule,
            "noTieRule": options.noTieRule
        ]
    }

    init?(from dict: [String: Any]) {
        guard dict["type"] as? String == WCMessageType.sessionStart.rawValue,
              let idStr = dict["sessionId"] as? String,
              let id = UUID(uuidString: idStr),
              let modeRaw = dict["mode"] as? String,
              let mode = MatchFormat(rawValue: modeRaw) else { return nil }
        sessionId = id
        options = MatchOptions(
            mode: mode,
            noAdRule: dict["noAdRule"] as? Bool ?? true,
            noTieRule: dict["noTieRule"] as? Bool ?? false
        )
    }

    init(sessionId: UUID, options: MatchOptions) {
        self.sessionId = sessionId
        self.options = options
    }
}

struct ScoreState {
    let myScore: Int
    let yourScore: Int
    let myGameScore: Int
    let yourGameScore: Int
    let mySetScore: Int
    let yourSetScore: Int
    let completedSets: [[Int]]
    let isTieBreak: Bool

    func toDictionary() -> [String: Any] {
        [
            "type": WCMessageType.scoreState.rawValue,
            "myScore": myScore,
            "yourScore": yourScore,
            "myGame": myGameScore,
            "yourGame": yourGameScore,
            "mySet": mySetScore,
            "yourSet": yourSetScore,
            "sets": completedSets,
            "tieBreak": isTieBreak
        ]
    }

    init?(from dict: [String: Any]) {
        guard dict["type"] as? String == WCMessageType.scoreState.rawValue,
              let myScore = dict["myScore"] as? Int,
              let yourScore = dict["yourScore"] as? Int,
              let myGame = dict["myGame"] as? Int,
              let yourGame = dict["yourGame"] as? Int,
              let mySet = dict["mySet"] as? Int,
              let yourSet = dict["yourSet"] as? Int else { return nil }
        self.myScore = myScore
        self.yourScore = yourScore
        myGameScore = myGame
        yourGameScore = yourGame
        mySetScore = mySet
        yourSetScore = yourSet
        completedSets = dict["sets"] as? [[Int]] ?? []
        isTieBreak = dict["tieBreak"] as? Bool ?? false
    }

    init(myScore: Int, yourScore: Int, myGameScore: Int, yourGameScore: Int,
         mySetScore: Int, yourSetScore: Int, completedSets: [[Int]], isTieBreak: Bool) {
        self.myScore = myScore
        self.yourScore = yourScore
        self.myGameScore = myGameScore
        self.yourGameScore = yourGameScore
        self.mySetScore = mySetScore
        self.yourSetScore = yourSetScore
        self.completedSets = completedSets
        self.isTieBreak = isTieBreak
    }
}

struct MatchEndMessage {
    let sessionId: UUID
    let result: String
    let completedSets: [[Int]]
    let startedAt: Date
    let endedAt: Date
    let calories: Double
    let averageHeartRate: Double?
    let mode: String
    let noAdRule: Bool

    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "type": WCMessageType.matchEnd.rawValue,
            "sessionId": sessionId.uuidString,
            "result": result,
            "sets": completedSets,
            "startedAt": startedAt.timeIntervalSince1970,
            "endedAt": endedAt.timeIntervalSince1970,
            "calories": calories,
            "mode": mode,
            "noAdRule": noAdRule
        ]
        if let hr = averageHeartRate { dict["heartRate"] = hr }
        return dict
    }

    init?(from dict: [String: Any]) {
        guard dict["type"] as? String == WCMessageType.matchEnd.rawValue,
              let idStr = dict["sessionId"] as? String,
              let id = UUID(uuidString: idStr),
              let result = dict["result"] as? String,
              let startTs = dict["startedAt"] as? Double,
              let endTs = dict["endedAt"] as? Double,
              let mode = dict["mode"] as? String else { return nil }
        sessionId = id
        self.result = result
        completedSets = dict["sets"] as? [[Int]] ?? []
        startedAt = Date(timeIntervalSince1970: startTs)
        endedAt = Date(timeIntervalSince1970: endTs)
        calories = dict["calories"] as? Double ?? 0
        averageHeartRate = dict["heartRate"] as? Double
        self.mode = mode
        noAdRule = dict["noAdRule"] as? Bool ?? true
    }

    init(sessionId: UUID, result: String, completedSets: [[Int]], startedAt: Date,
         endedAt: Date, calories: Double, averageHeartRate: Double?, mode: String, noAdRule: Bool) {
        self.sessionId = sessionId
        self.result = result
        self.completedSets = completedSets
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.calories = calories
        self.averageHeartRate = averageHeartRate
        self.mode = mode
        self.noAdRule = noAdRule
    }
}

// MARK: - Service

final class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published var isWatchReachable: Bool = false
    @Published var receivedSessionStart: SessionStartMessage?
    @Published var receivedScoreState: ScoreState?
    @Published var receivedMatchEnd: MatchEndMessage?
    @Published var receivedMetrics: WorkoutMetrics?
    @Published var receivedWorkoutEnd: Date?

    override private init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendSessionStart(_ msg: SessionStartMessage) {
        send(msg.toDictionary())
    }

    func sendScoreState(_ state: ScoreState) {
        send(state.toDictionary())
    }

    func sendMatchEnd(_ msg: MatchEndMessage) {
        let dict = msg.toDictionary()
        guard WCSession.default.activationState == .activated else { return }
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(dict, replyHandler: nil, errorHandler: nil)
        } else {
            WCSession.default.transferUserInfo(dict)
        }
    }

    func sendMetrics(_ metrics: WorkoutMetrics) {
        send(metrics.toDictionary())
    }

    func sendWorkoutEnd() {
        send(["type": WCMessageType.workoutEnd.rawValue])
    }

    private func send(_ dict: [String: Any]) {
        guard WCSession.default.activationState == .activated else { return }
        #if os(iOS)
        guard WCSession.default.isWatchAppInstalled else { return }
        #endif
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(dict, replyHandler: nil, errorHandler: nil)
        } else {
            try? WCSession.default.updateApplicationContext(dict)
        }
    }

    private func handle(_ message: [String: Any]) {
        DispatchQueue.main.async {
            switch message["type"] as? String {
            case WCMessageType.sessionStart.rawValue:
                self.receivedSessionStart = SessionStartMessage(from: message)
            case WCMessageType.scoreState.rawValue:
                self.receivedScoreState = ScoreState(from: message)
            case WCMessageType.matchEnd.rawValue:
                self.receivedMatchEnd = MatchEndMessage(from: message)
            case WCMessageType.metrics.rawValue:
                self.receivedMetrics = WorkoutMetrics(from: message)
            case WCMessageType.workoutEnd.rawValue:
                self.receivedWorkoutEnd = Date()
            default:
                break
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith _: WCSessionActivationState, error _: Error?) {
        DispatchQueue.main.async { self.isWatchReachable = session.isReachable }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.isWatchReachable = session.isReachable }
    }

    func session(_: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    func session(_: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handle(applicationContext)
    }

    func session(_: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handle(userInfo)
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_: WCSession) {}
    func sessionDidDeactivate(_: WCSession) {
        WCSession.default.activate()
    }
    #endif
}
