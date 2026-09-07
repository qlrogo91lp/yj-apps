import ConnectivityCore
import Foundation

/// 워치 → 폰 워크아웃 저장 요청. **저장 시점에 결과와 세그먼트를 한 번만 보낸다** —
/// 세션 중 폰 화면에 세그먼트를 띄울 계획이 없으므로 실시간 전환 메시지는 두지 않는다 (아키텍처 8절).
///
/// `.reliable` 로 보낸다. 폰이 꺼져 있어도 `transferUserInfo` 가 큐잉하므로 기록이 유실되지 않는다.
struct WorkoutRecordMessage: ConnectivityMessage {
    static let messageType = "workoutRecord"

    /// HealthKit 워크아웃 UUID. 폰이 이 값으로 중복을 걸러낸다. 저장에 실패했으면 nil.
    let healthKitUUID: UUID?
    let startedAt: Date
    let endedAt: Date
    let totalSeconds: Int
    let activeCalories: Double
    let totalCalories: Double
    let averageHeartRate: Double?
    let segments: [SegmentPayload]

    /// 와이어에 실리는 구간. `Segment` 는 `@Model` 이라 그대로 보낼 수 없다.
    struct SegmentPayload {
        let kind: SegmentKind
        let startOffset: Int
        let durationSeconds: Int
    }

    init(healthKitUUID: UUID?,
         startedAt: Date,
         endedAt: Date,
         totalSeconds: Int,
         activeCalories: Double,
         totalCalories: Double,
         averageHeartRate: Double?,
         segments: [SegmentPayload])
    {
        self.healthKitUUID = healthKitUUID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.totalSeconds = totalSeconds
        self.activeCalories = activeCalories
        self.totalCalories = totalCalories
        self.averageHeartRate = averageHeartRate
        self.segments = segments
    }

    init?(from dictionary: [String: Any]) {
        guard let started = dictionary["startedAt"] as? TimeInterval,
              let ended = dictionary["endedAt"] as? TimeInterval else { return nil }

        healthKitUUID = (dictionary["healthKitUUID"] as? String).flatMap(UUID.init(uuidString:))
        startedAt = Date(timeIntervalSince1970: started)
        endedAt = Date(timeIntervalSince1970: ended)
        totalSeconds = dictionary["totalSeconds"] as? Int ?? 0
        activeCalories = dictionary["activeCalories"] as? Double ?? 0
        totalCalories = dictionary["totalCalories"] as? Double ?? 0
        averageHeartRate = dictionary["averageHeartRate"] as? Double

        // 구간이 하나도 안 실려 오면 빈 배열로 둔다 — 기록 자체는 살린다.
        let raw = dictionary["segments"] as? [[String: Any]] ?? []
        segments = raw.compactMap { entry in
            guard let kindRaw = entry["kind"] as? String,
                  let kind = SegmentKind(rawValue: kindRaw) else { return nil }
            return SegmentPayload(kind: kind,
                                  startOffset: entry["startOffset"] as? Int ?? 0,
                                  durationSeconds: entry["durationSeconds"] as? Int ?? 0)
        }
    }

    func toDictionary() -> [String: Any] {
        var dictionary: [String: Any] = [
            "startedAt": startedAt.timeIntervalSince1970,
            "endedAt": endedAt.timeIntervalSince1970,
            "totalSeconds": totalSeconds,
            "activeCalories": activeCalories,
            "totalCalories": totalCalories,
            "segments": segments.map {
                ["kind": $0.kind.rawValue,
                 "startOffset": $0.startOffset,
                 "durationSeconds": $0.durationSeconds]
            },
        ]
        // WCSession 은 nil 값을 담을 수 없다 — 있을 때만 넣고 수신 측이 없으면 nil 로 읽는다.
        if let healthKitUUID { dictionary["healthKitUUID"] = healthKitUUID.uuidString }
        if let averageHeartRate { dictionary["averageHeartRate"] = averageHeartRate }
        return dictionary
    }
}
