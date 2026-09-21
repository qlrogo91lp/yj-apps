import Combine
import Foundation

/// 워크아웃 종료 메시지의 최종값을 세션 레코드로 저장한다.
///
/// **앱이 살아 있는 내내 살아 있어야 한다.** 경기를 한 판도 저장하지 않은 워크아웃은 iOS 에
/// `sessionStart` 가 오지 않아 `WorkoutSessionView` 자체가 뜨지 않는다. 저장을 화면이 소유한
/// ViewModel 에 두면 그 워크아웃은 받을 주체가 없어 기록이 통째로 사라진다 — 저장 책임을
/// 화면에서 떼어 앱 루트로 올린 이유다.
///
/// 소비는 `receivedSessionResult` 만 비운다. `receivedWorkoutEnd` 는 화면 종료를 맡은
/// ViewModel 의 소비 대상이라 건드리면 경기 화면이 안 닫힌다.
final class WorkoutSessionRecorder {
    private let connectivity: MatchConnectivity
    private let persistence: SessionPersistenceService
    private var cancellables = Set<AnyCancellable>()

    init(connectivity: MatchConnectivity = .shared,
         persistence: SessionPersistenceService = .shared)
    {
        self.connectivity = connectivity
        self.persistence = persistence

        connectivity.$receivedSessionResult
            .compactMap(\.self)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in self?.record(message) }
            .store(in: &cancellables)
    }

    /// 최종값이 하나도 없으면(구버전 워치) 저장하지 않는다 — 빈 레코드가 폴백을 가로막는다.
    @discardableResult
    func record(_ message: WorkoutEndMessage) -> WorkoutSessionRecord? {
        connectivity.receivedSessionResult = nil

        guard message.elapsedSeconds != nil
            || message.activeCalories != nil
            || message.averageHeartRate != nil
        else { return nil }

        let record = WorkoutSessionRecord()
        record.workoutSessionId = message.sessionId
        record.startedAt = message.startedAt ?? Date()
        record.endedAt = message.endedAt
        record.elapsedSeconds = message.elapsedSeconds
        record.activeCalories = message.activeCalories
        record.totalCalories = message.totalCalories
        record.averageHeartRate = message.averageHeartRate
        record.healthKitUUID = message.healthKitUUID
        try? persistence.upsert(record)
        return record
    }
}
