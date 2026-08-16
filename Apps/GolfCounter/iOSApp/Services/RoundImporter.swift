import Foundation
import SwiftData

/// 워치에서 도착한 완료 라운드를 SwiftData에 적재한다 (spec §6).
///
/// WatchConnectivity를 모르기 때문에 인메모리 컨테이너로 테스트할 수 있다 —
/// 세션 등록은 `RoundReceiveService`가 맡는다.
@MainActor
struct RoundImporter {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// 같은 `id`의 라운드가 이미 있으면 저장하지 않는다.
    /// transferUserInfo 재배달과 "전송 후 스냅샷 삭제 전 크래시 → 복구 후 재전송"을 함께 막는다 (spec §6).
    /// - Returns: 실제로 저장했으면 true. 중복이거나 저장에 실패하면 false.
    @discardableResult
    func save(_ message: RoundCompletedMessage) -> Bool {
        let id = message.id
        let descriptor = FetchDescriptor<GolfRound>(predicate: #Predicate { $0.id == id })
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return false }

        let round = GolfRound()
        round.id = message.id
        round.startedAt = message.startedAt
        round.endedAt = message.endedAt
        round.courseName = message.courseName
        round.holeScores = message.holeScores
        round.holePars = message.holePars
        round.puttCounts = message.puttCounts
        round.calories = message.metrics.calories
        round.avgHeartRate = message.metrics.avgHeartRate
        round.distanceMeters = message.metrics.distanceMeters
        round.steps = message.metrics.steps

        context.insert(round)
        do {
            try context.save()
        } catch {
            // 저장이 깨지면 반쯤 들어간 라운드를 남기지 않는다. 워치는 재전송하지 않으므로
            // 이 라운드는 유실되지만, 잘못된 레코드를 남기는 것보다 낫다 (spec §8).
            context.rollback()
            return false
        }
        return true
    }
}
