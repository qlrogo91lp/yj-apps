import ActivityKit
import Foundation

@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()
    private var activity: Activity<TennisActivityAttributes>?

    private init() {}

    func start(mode: MatchFormat) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = TennisActivityAttributes(matchMode: mode.rawValue)
        activity = try? Activity.request(
            attributes: attributes,
            contentState: .empty,
            pushType: nil
        )
    }

    func update(from state: ScoreState, score: Score) {
        let contentState = TennisActivityAttributes.ContentState(
            myPoint: state.isTieBreak ? "\(state.myScore)" : score.myDisplayScore,
            yourPoint: state.isTieBreak ? "\(state.yourScore)" : score.yourDisplayScore,
            myGame: state.myGameScore,
            yourGame: state.yourGameScore,
            mySet: state.mySetScore,
            yourSet: state.yourSetScore,
            isTieBreak: state.isTieBreak
        )
        Task { await activity?.update(using: contentState) }
    }

    func end() {
        Task { await activity?.end(dismissalPolicy: .immediate) }
        activity = nil
    }
}
