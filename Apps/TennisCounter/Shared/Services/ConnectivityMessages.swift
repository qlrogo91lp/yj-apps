import ConnectivityCore
import Foundation

// MARK: - 세션 시작

struct SessionStartMessage: ConnectivityMessage {
    static let messageType = "sessionStart"

    let sessionId: UUID
    let options: MatchOptions
    let workoutStartDate: Date

    func toDictionary() -> [String: Any] {
        [
            "type": Self.messageType,
            "sessionId": sessionId.uuidString,
            "mode": options.mode.rawValue,
            "noAdRule": options.noAdRule,
            "noTieRule": options.noTieRule,
            "gameThreshold": options.gameThreshold,
            "workoutStartDate": workoutStartDate.timeIntervalSince1970,
        ]
    }

    init?(from dict: [String: Any]) {
        guard dict["type"] as? String == Self.messageType,
              let idStr = dict["sessionId"] as? String,
              let id = UUID(uuidString: idStr),
              let modeRaw = dict["mode"] as? String,
              let mode = MatchFormat(rawValue: modeRaw) else { return nil }
        sessionId = id
        options = MatchOptions(
            mode: mode,
            noAdRule: dict["noAdRule"] as? Bool ?? true,
            noTieRule: dict["noTieRule"] as? Bool ?? false,
            gameThreshold: dict["gameThreshold"] as? Int ?? 6
        )
        let ts = dict["workoutStartDate"] as? Double ?? Date().timeIntervalSince1970
        workoutStartDate = Date(timeIntervalSince1970: ts)
    }

    init(sessionId: UUID, options: MatchOptions, workoutStartDate: Date = Date()) {
        self.sessionId = sessionId
        self.options = options
        self.workoutStartDate = workoutStartDate
    }
}

// MARK: - 점수 상태

struct ScoreState: ConnectivityMessage {
    static let messageType = "scoreState"

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
            "type": Self.messageType,
            "myScore": myScore,
            "yourScore": yourScore,
            "myGame": myGameScore,
            "yourGame": yourGameScore,
            "mySet": mySetScore,
            "yourSet": yourSetScore,
            "sets": completedSets,
            "tieBreak": isTieBreak,
        ]
    }

    init?(from dict: [String: Any]) {
        guard dict["type"] as? String == Self.messageType,
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
         mySetScore: Int, yourSetScore: Int, completedSets: [[Int]], isTieBreak: Bool)
    {
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

// MARK: - 경기 종료/저장

struct MatchEndMessage: ConnectivityMessage {
    static let messageType = "matchEnd"

    let sessionId: UUID
    let result: String
    let completedSets: [[Int]]
    let startedAt: Date
    let endedAt: Date
    let durationSeconds: Int
    let calories: Double
    let averageHeartRate: Double?
    let mode: String
    let noAdRule: Bool

    func toDictionary() -> [String: Any] {
        dictionary(type: Self.messageType)
    }

    /// 사용자가 저장 버튼을 눌렀을 때 전송하는 페이로드 (iOS가 이때만 persist)
    func toSaveDictionary() -> [String: Any] {
        dictionary(type: MatchSaveMessage.messageType)
    }

    private func dictionary(type: String) -> [String: Any] {
        var dict: [String: Any] = [
            "type": type,
            "sessionId": sessionId.uuidString,
            "result": result,
            "sets": completedSets,
            "startedAt": startedAt.timeIntervalSince1970,
            "endedAt": endedAt.timeIntervalSince1970,
            "durationSeconds": durationSeconds,
            "calories": calories,
            "mode": mode,
            "noAdRule": noAdRule,
        ]
        if let hr = averageHeartRate { dict["heartRate"] = hr }
        return dict
    }

    init?(from dict: [String: Any]) {
        let type = dict["type"] as? String
        guard type == Self.messageType || type == MatchSaveMessage.messageType,
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
        durationSeconds = dict["durationSeconds"] as? Int ?? Int(endTs - startTs)
        calories = dict["calories"] as? Double ?? 0
        averageHeartRate = dict["heartRate"] as? Double
        self.mode = mode
        noAdRule = dict["noAdRule"] as? Bool ?? true
    }

    init(sessionId: UUID, result: String, completedSets: [[Int]], startedAt: Date,
         endedAt: Date, durationSeconds: Int, calories: Double, averageHeartRate: Double?, mode: String, noAdRule: Bool)
    {
        self.sessionId = sessionId
        self.result = result
        self.completedSets = completedSets
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.calories = calories
        self.averageHeartRate = averageHeartRate
        self.mode = mode
        self.noAdRule = noAdRule
    }
}

/// MatchEndMessage와 같은 페이로드를 "matchSave" 타입으로 실어 나르는 래퍼.
/// 결과 표시(matchEnd)와 저장 요청(matchSave)을 타입 라우팅으로 구분하기 위해 존재한다.
struct MatchSaveMessage: ConnectivityMessage {
    static let messageType = "matchSave"

    let base: MatchEndMessage

    init(base: MatchEndMessage) {
        self.base = base
    }

    init?(from dictionary: [String: Any]) {
        guard dictionary["type"] as? String == Self.messageType,
              let base = MatchEndMessage(from: dictionary) else { return nil }
        self.base = base
    }

    func toDictionary() -> [String: Any] {
        base.toSaveDictionary()
    }
}

struct MatchSaveResultMessage: ConnectivityMessage {
    static let messageType = "matchSaveResult"

    let sessionId: UUID
    let success: Bool

    func toDictionary() -> [String: Any] {
        [
            "type": Self.messageType,
            "sessionId": sessionId.uuidString,
            "success": success,
        ]
    }

    init?(from dict: [String: Any]) {
        guard dict["type"] as? String == Self.messageType,
              let idStr = dict["sessionId"] as? String,
              let id = UUID(uuidString: idStr),
              let success = dict["success"] as? Bool else { return nil }
        sessionId = id
        self.success = success
    }

    init(sessionId: UUID, success: Bool) {
        self.sessionId = sessionId
        self.success = success
    }
}

// MARK: - 신호 메시지 (구 서비스에서는 raw dict였던 것들 — type/sentAt은 코어가 스탬프)

struct WorkoutEndMessage: ConnectivityMessage {
    static let messageType = "workoutEnd"

    let sessionId: UUID

    init(sessionId: UUID) {
        self.sessionId = sessionId
    }

    init?(from dictionary: [String: Any]) {
        guard let idStr = dictionary["sessionId"] as? String,
              let id = UUID(uuidString: idStr) else { return nil }
        sessionId = id
    }

    func toDictionary() -> [String: Any] {
        ["sessionId": sessionId.uuidString]
    }
}

/// 드라이버가 진행 중 매치를 중간에 버릴 때(뒤로가기) 미러도 모드선택으로 돌아가게 하는 신호.
struct MatchResetMessage: ConnectivityMessage {
    static let messageType = "matchReset"

    let sessionId: UUID

    init(sessionId: UUID) {
        self.sessionId = sessionId
    }

    init?(from dictionary: [String: Any]) {
        guard let idStr = dictionary["sessionId"] as? String,
              let id = UUID(uuidString: idStr) else { return nil }
        sessionId = id
    }

    func toDictionary() -> [String: Any] {
        ["sessionId": sessionId.uuidString]
    }
}

// MARK: - 기존 모델 conformance

extension WorkoutMetrics: ConnectivityMessage {
    static let messageType = "metrics"
}
