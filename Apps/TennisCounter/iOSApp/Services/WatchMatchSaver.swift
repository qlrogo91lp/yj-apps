import Combine
import Foundation
import MonitoringCore

/// 워치가 보낸 경기 저장 요청을 받아 저장하고 결과 ACK 를 회신한다.
///
/// **앱이 살아 있는 내내 살아 있어야 한다.** 저장을 경기 화면의 ViewModel 에 두면 폰에 경기 화면이
/// 없을 때 받을 주체가 없어 저장도 ACK 도 없다 — 워치가 재시도해도 같은 경로라 결과가 같다.
/// `WorkoutSessionRecorder` 와 같은 이유로 저장 책임을 앱 루트로 올렸다.
///
/// 중복 배달(큐 재전송 등)은 `matchId` 기준 upsert 라 안전하다.
@MainActor
final class WatchMatchSaver {
    private let store: MatchUpserting
    private let crashReporter: CrashReporting
    private let sendResult: (MatchSaveResultMessage) -> Void
    private var cancellables = Set<AnyCancellable>()

    init(connectivity: MatchConnectivity = .shared,
         store: MatchUpserting = MatchPersistenceService.shared,
         crashReporter: CrashReporting = AppCrashReporter.current,
         sendResult: @escaping (MatchSaveResultMessage) -> Void = { MatchConnectivity.shared.sendMatchSaveResult($0) })
    {
        self.store = store
        self.crashReporter = crashReporter
        self.sendResult = sendResult

        connectivity.$receivedMatchSave
            .compactMap(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak connectivity] message in
                connectivity?.receivedMatchSave = nil
                self?.save(message)
            }
            .store(in: &cancellables)
    }

    func save(_ msg: MatchEndMessage) {
        let match = Self.buildMatch(from: msg)
        var success = true
        crashReporter.log("save attempted (watch)")
        do { try store.upsert(match) } catch {
            success = false
            crashReporter.record(
                MonitoringError(domain: "Ralli.Save", code: 2, message: "\(error)"),
                context: ["source": "watch", "sessionId": msg.sessionId.uuidString]
            )
        }
        sendResult(MatchSaveResultMessage(sessionId: msg.sessionId, success: success))
    }

    private static func buildMatch(from msg: MatchEndMessage) -> Match {
        let match = Match()
        match.matchId = msg.matchId
        match.workoutSessionId = msg.sessionId
        match.startedAt = msg.startedAt
        match.endedAt = msg.endedAt
        match.durationSeconds = msg.durationSeconds
        match.caloriesBurned = msg.calories
        match.totalCaloriesBurned = msg.totalCalories
        match.workoutElapsedSeconds = msg.workoutElapsedSeconds
        match.workoutCaloriesBurned = msg.workoutCalories
        match.workoutTotalCaloriesBurned = msg.workoutTotalCalories
        match.averageHeartRate = msg.averageHeartRate
        match.mode = msg.mode
        match.noAdRule = msg.noAdRule
        match.resultRaw = msg.result
        match.myTotalSets = msg.completedSets.count(where: { $0[0] > $0[1] })
        match.yourTotalSets = msg.completedSets.count(where: { $0[1] > $0[0] })
        match.sets = msg.completedSets.enumerated().map {
            SetRecord(myGames: $0.element[0], yourGames: $0.element[1], setNumber: $0.offset + 1)
        }
        return match
    }
}
