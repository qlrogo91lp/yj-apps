import Foundation

class MatchSession {
    let id: UUID
    let workoutSessionId: UUID
    let options: MatchOptions
    let startedAt: Date
    var endedAt: Date?
    var result: MatchResult?

    var mySetScore: Int = 0
    var yourSetScore: Int = 0
    var completedSets: [SetScore] = []

    let kcalAtStart: Double
    var kcalAtEnd: Double?
    var averageHeartRate: Double?

    init(id: UUID = UUID(), workoutSessionId: UUID, options: MatchOptions,
         startedAt: Date = Date(), kcalAtStart: Double)
    {
        self.id = id
        self.workoutSessionId = workoutSessionId
        self.options = options
        self.startedAt = startedAt
        self.kcalAtStart = kcalAtStart
    }
}
