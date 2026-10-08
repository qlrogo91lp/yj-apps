import Foundation

/// 통계 화면이 표시할 연 단위 값. 화면 레이어에는 계산 규칙을 두지 않는다.
struct StatisticsDashboard: Equatable {
    struct Frequency: Equatable, Identifiable {
        let id: Int
        let title: String
        let count: Int
        let isFuture: Bool
        let isHighlighted: Bool
    }

    struct BodyFrequency: Equatable, Identifiable {
        let part: BodyPart
        let count: Int

        var id: BodyPart { part }
    }

    struct Composition: Equatable {
        let strengthSeconds: Int
        let cardioSeconds: Int
        let strengthPercent: Int
        let cardioPercent: Int
        let strengthText: String
        let cardioText: String
    }

    struct Milestone: Equatable, Identifiable {
        let target: Int
        let remaining: Int
        let isAchieved: Bool

        var id: Int { target }
    }

    let year: Int
    let availableYears: [Int]
    let countText: String
    let durationText: String
    let weeklyAverageText: String
    let weeklyAverageExplanation: String
    let isCurrentYear: Bool
    let emptyMessage: String?
    let months: [Frequency]
    let weekdays: [Frequency]
    let composition: Composition?
    let bodyParts: [BodyFrequency]
    let milestones: [Milestone]
    let gridDays: [Date]
    let grassLevels: [Date: GrassLevel]
    let monthColumns: [Int: Int]
    let initialColumn: Int
    let today: Date
}
