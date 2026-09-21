import Foundation
import SwiftData
@testable import TennisCounter
import Testing

@MainActor
struct SessionRecordSavingTests {
    /// 레코더는 `MatchConnectivity.shared` 를 구독한다. 다른 스위트가 병렬로 흘린 메시지가
    /// 이 테스트의 저장소에 섞일 수 있어, 전체 개수가 아니라 이 테스트의 sessionId 로 좁혀 센다.
    private func count(_ persistence: SessionPersistenceService, _ sessionId: UUID) throws -> Int {
        try persistence.fetchAll().count(where: { $0.workoutSessionId == sessionId })
    }

    private func makePersistence() throws -> SessionPersistenceService {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WorkoutSessionRecord.self, configurations: config)
        let service = SessionPersistenceService()
        service.configure(with: ModelContext(container))
        return service
    }

    private func makeMessage(
        sessionId: UUID = UUID(),
        startedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> WorkoutEndMessage {
        WorkoutEndMessage(
            sessionId: sessionId,
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(9351),
            elapsedSeconds: 9351,
            activeCalories: 1343,
            totalCalories: 1584,
            averageHeartRate: 136
        )
    }

    @Test func buildsRecordFromMessage() throws {
        let persistence = try makePersistence()
        let recorder = WorkoutSessionRecorder(persistence: persistence)
        let sessionId = UUID()
        let started = Date(timeIntervalSince1970: 1_700_000_000)

        let record = try #require(recorder.record(makeMessage(sessionId: sessionId, startedAt: started)))

        #expect(record.workoutSessionId == sessionId)
        #expect(record.elapsedSeconds == 9351)
        #expect(record.averageHeartRate == 136)
        #expect(record.startedAt == started)
        #expect(try count(persistence, sessionId) == 1)
    }

    /// 구버전 워치가 보낸 메시지는 최종값이 없다 — 레코드를 만들지 않는다.
    @Test func skipsWhenNoFinalValues() throws {
        let persistence = try makePersistence()
        let recorder = WorkoutSessionRecorder(persistence: persistence)
        let sessionId = UUID()

        #expect(recorder.record(WorkoutEndMessage(sessionId: sessionId)) == nil)
        #expect(try count(persistence, sessionId) == 0)
    }

    /// 경기를 한 판도 저장하지 않은 워크아웃은 iOS 에 sessionStart 가 오지 않아 경기 화면이 뜨지
    /// 않는다. 그래도 레코드는 남아야 "경기 없음" 세션 카드가 생긴다 — 레코더가 화면과 무관하게
    /// 살아 있는 이유이고, 저장을 화면 ViewModel 이 갖고 있었을 때 이 경로가 통째로 비어 있었다.
    @Test func savesWhenMatchScreenNeverOpened() async throws {
        let persistence = try makePersistence()
        let recorder = WorkoutSessionRecorder(persistence: persistence)
        let connectivity = MatchConnectivity.shared
        let sessionId = UUID()

        connectivity.receivedSessionResult = makeMessage(sessionId: sessionId)
        try await Task.sleep(for: .milliseconds(50))

        #expect(try count(persistence, sessionId) == 1)
        // 기록 채널만 비운다 — 화면 종료를 맡은 receivedWorkoutEnd 는 ViewModel 의 소비 대상이다.
        #expect(connectivity.receivedSessionResult == nil)

        withExtendedLifetime(recorder) {}
    }

    /// 같은 워크아웃의 메시지가 늦게 한 번 더 와도 레코드는 하나다 (upsert 키는 workoutSessionId).
    @Test func duplicateMessageDoesNotAddSecondRecord() throws {
        let persistence = try makePersistence()
        let recorder = WorkoutSessionRecorder(persistence: persistence)
        let sessionId = UUID()

        recorder.record(makeMessage(sessionId: sessionId))
        recorder.record(makeMessage(sessionId: sessionId))

        #expect(try count(persistence, sessionId) == 1)
    }
}
