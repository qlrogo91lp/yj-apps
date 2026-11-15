import ActivityKit
import Foundation

@MainActor final class LiveActivityController {
    private var activity: Activity<HanjanActivityAttributes>?

    func sync(_ session: LiveSession?, kindName: String) {
        guard let session, session.endedAt == nil else {
            let existing = Activity<HanjanActivityAttributes>.activities
            activity = nil
            Task { for item in existing {
                await item.end(nil, dismissalPolicy: .immediate)
            } }
            return
        }
        let progress = session.toastProgress
        let state = HanjanActivityAttributes.ContentState(kindName: kindName, equivalent: session.ledger.sojuEquivalent(), limit: session.limit,
                                                          toastFilled: progress?.filled, toastTotal: progress?.total,
                                                          toastOnly: progress.map { !$0.isDrinkTurn } ?? false)
        let content = ActivityContent(state: state, staleDate: nil)
        let activities = Activity<HanjanActivityAttributes>.activities
        let stale = activities.filter { $0.attributes.sessionId != session.id }
        if !stale.isEmpty { Task { for item in stale {
            await item.end(nil, dismissalPolicy: .immediate)
        } } }
        let currentActivity = activity.flatMap { $0.attributes.sessionId == session.id ? $0 : nil }
        if let current = currentActivity ?? activities.first(where: { $0.attributes.sessionId == session.id }) {
            activity = current
            Task { await current.update(content) }
        } else if ActivityAuthorizationInfo().areActivitiesEnabled {
            activity = nil
            activity = try? Activity.request(attributes: HanjanActivityAttributes(sessionId: session.id), content: content, pushType: nil)
        }
    }
}
