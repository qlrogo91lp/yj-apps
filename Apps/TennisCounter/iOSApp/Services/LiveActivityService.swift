import ActivityKit
import Foundation

@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    private var activity: Activity<TennisActivityAttributes>?
    private var workoutStartTime: Date?

    private init() {}

    func start(mode: MatchFormat) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let startTime = Date.now
        workoutStartTime = startTime
        let stale = activity
        let attributes = TennisActivityAttributes(matchMode: mode.rawValue)
        var initial = TennisActivityAttributes.ContentState.empty
        initial.workoutStartTime = startTime
        let requested = try? Activity.request(
            attributes: attributes,
            contentState: initial,
            pushType: nil
        )
        activity = requested
        Task {
            await stale?.end(dismissalPolicy: .immediate)
            for other in Activity<TennisActivityAttributes>.activities where other.id != requested?.id {
                await other.end(dismissalPolicy: .immediate)
            }
        }
    }

    func endAll() {
        let current = activity
        activity = nil
        workoutStartTime = nil
        Task {
            await current?.end(dismissalPolicy: .immediate)
            for other in Activity<TennisActivityAttributes>.activities {
                await other.end(dismissalPolicy: .immediate)
            }
        }
    }

    func update(from state: ScoreState, score: Score) {
        let contentState = TennisActivityAttributes.ContentState(
            myPoint: state.isTieBreak ? "\(state.myScore)" : score.myDisplayScore,
            yourPoint: state.isTieBreak ? "\(state.yourScore)" : score.yourDisplayScore,
            myGame: state.myGameScore,
            yourGame: state.yourGameScore,
            mySet: state.mySetScore,
            yourSet: state.yourSetScore,
            isTieBreak: state.isTieBreak,
            workoutStartTime: workoutStartTime
        )
        Task { await activity?.update(using: contentState) }
    }

    func end() {
        let current = activity
        Task { await current?.end(dismissalPolicy: .immediate) }
        activity = nil
        workoutStartTime = nil
    }
}
