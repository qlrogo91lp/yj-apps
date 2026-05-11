import Foundation
import SwiftData

@Model
final class MatchRecord {
    var id: UUID = UUID()
    var mode: String = MatchMode.oneSet.rawValue // store rawValue (MatchMode is not directly supported by SwiftData transformable easily)
    var noAdRule: Bool = true
    var startedAt: Date = Date()
    var endedAt: Date = Date()
    var resultRaw: String = MatchResult.win.rawValue

    var mySetScore: Int = 0
    var yourSetScore: Int = 0

    var durationSeconds: Int = 0
    var caloriesBurned: Double = 0
    var averageHeartRate: Double?
    var workoutSessionId: UUID?

    /// Stored as JSON since SwiftData doesn't support [SetScore] directly
    var completedSetsJSON: String = "[]"

    var matchMode: MatchMode {
        get { MatchMode(rawValue: mode) ?? .oneSet }
        set { mode = newValue.rawValue }
    }

    var matchResult: MatchResult {
        get { MatchResult(rawValue: resultRaw) ?? .win }
        set { resultRaw = newValue.rawValue }
    }

    var completedSets: [SetScore] {
        get {
            let data = completedSetsJSON.data(using: .utf8) ?? Data()
            return (try? JSONDecoder().decode([SetScore].self, from: data)) ?? []
        }
        set {
            let data = (try? JSONEncoder().encode(newValue)) ?? Data()
            completedSetsJSON = String(data: data, encoding: .utf8) ?? "[]"
        }
    }

    init(from session: MatchSession) {
        id = session.id
        mode = session.options.mode.rawValue
        noAdRule = session.options.noAdRule
        startedAt = session.startedAt
        endedAt = session.endedAt ?? Date()
        resultRaw = session.result?.rawValue ?? MatchResult.win.rawValue
        mySetScore = session.mySetScore
        yourSetScore = session.yourSetScore
        durationSeconds = Int((session.endedAt ?? Date()).timeIntervalSince(session.startedAt))
        caloriesBurned = (session.kcalAtEnd ?? 0) - session.kcalAtStart
        averageHeartRate = session.averageHeartRate
        workoutSessionId = session.workoutSessionId
        completedSets = session.completedSets
    }
}
