import ConnectivityCore
import Foundation

/// 라운드 완료 시 워치 → iOS 단방향 전송 페이로드 (spec §4).
///
/// 필드는 `GolfRound`와 1:1이다 — iOS(plan ⑤)는 이걸 그대로 옮겨 담아 저장한다.
/// `WorkoutResult.durationSeconds`·`totalCaloriesBurned`는 `GolfRound`에 대응 필드가 없어
/// 싣지 않는다(소요 시간은 `endedAt - startedAt`으로 파생).
///
/// **이 파일은 `import ConnectivityCore` 때문에 컴플리케이션 타깃에서 제외되어 있다**
/// (pbxproj의 `PBXFileSystemSynchronizedBuildFileExceptionSet`). 컴플리케이션은
/// ralli-kit을 하나도 링크하지 않는다.
struct RoundCompletedMessage: ConnectivityMessage, Equatable {
    static let messageType = "roundCompleted"

    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let courseName: String?
    let holeScores: [Int]
    let holePars: [Int]
    let puttCounts: [Int]
    let metrics: RoundMetrics

    init(id: UUID,
         startedAt: Date,
         endedAt: Date,
         courseName: String?,
         holeScores: [Int],
         holePars: [Int],
         puttCounts: [Int],
         metrics: RoundMetrics)
    {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.courseName = courseName
        self.holeScores = holeScores
        self.holePars = holePars
        self.puttCounts = puttCounts
        self.metrics = metrics
    }

    init?(from dictionary: [String: Any]) {
        guard let idString = dictionary["id"] as? String,
              let id = UUID(uuidString: idString),
              let startedAt = dictionary["startedAt"] as? TimeInterval,
              let endedAt = dictionary["endedAt"] as? TimeInterval,
              let holeScores = dictionary["holeScores"] as? [Int],
              let holePars = dictionary["holePars"] as? [Int],
              let puttCounts = dictionary["puttCounts"] as? [Int]
        else { return nil }

        self.init(id: id,
                  startedAt: Date(timeIntervalSince1970: startedAt),
                  endedAt: Date(timeIntervalSince1970: endedAt),
                  courseName: dictionary["courseName"] as? String,
                  holeScores: holeScores,
                  holePars: holePars,
                  puttCounts: puttCounts,
                  metrics: RoundMetrics(calories: dictionary["calories"] as? Double ?? 0,
                                        avgHeartRate: dictionary["avgHeartRate"] as? Double ?? 0,
                                        distanceMeters: dictionary["distanceMeters"] as? Double ?? 0,
                                        steps: dictionary["steps"] as? Int ?? 0))
    }

    func toDictionary() -> [String: Any] {
        var dictionary: [String: Any] = [
            "id": id.uuidString,
            "startedAt": startedAt.timeIntervalSince1970,
            "endedAt": endedAt.timeIntervalSince1970,
            "holeScores": holeScores,
            "holePars": holePars,
            "puttCounts": puttCounts,
            "calories": metrics.calories,
            "avgHeartRate": metrics.avgHeartRate,
            "distanceMeters": metrics.distanceMeters,
            "steps": metrics.steps,
        ]
        // nil을 키로 남기면 WCSession 직렬화에서 NSNull이 되어 수신측 캐스팅이 어긋난다.
        if let courseName {
            dictionary["courseName"] = courseName
        }
        return dictionary
    }
}
